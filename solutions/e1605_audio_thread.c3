// =====================================================================
//  e1605 · Аудиопоток и lock-free очередь команд
// =====================================================================
//
//  Звуковая карта забирает данные по таймеру: если очередной блок
//  (скажем, 512 кадров = 10.7 мс при 48 кГц) не готов вовремя, вы
//  услышите щелчок (underrun). Поэтому микшер живёт в ОТДЕЛЬНОМ потоке
//  с высоким приоритетом, и у этого потока есть «золотые правила»:
//
//      * не брать мьютексы (поток игры может держать его 30 мс);
//      * не выделять память (malloc может взять внутренний лок);
//      * не ходить в файловую систему, не печатать, не ждать.
//
//  Как тогда игре сказать «сыграй взрыв»? Через lock-free очередь
//  с ОДНИМ производителем и ОДНИМ потребителем (SPSC):
//
//      поток игры                         аудиопоток
//      ----------                         ----------
//      push(PLAY ...) --> [ кольцевой буфер ] --> pop() каждый блок
//                 tail (пишет игра)    head (пишет аудио)
//
//  Индексы head/tail растут бесконечно (uint, переполнение по модулю
//  2^32 безопасно), ячейка = index % CAP. Пусто: head == tail.
//  Полно: tail - head == CAP.
//
//  Порядок памяти — главное:
//    push: записать ячейку, ПОТОМ tail.store(t + 1, RELEASE);
//          head читаем с ACQUIRE (чтобы не перезаписать ячейку,
//          которую потребитель ещё читает).
//    pop:  tail.load(ACQUIRE) — гарантирует, что ячейку мы увидим
//          уже записанной; прочитать ячейку, ПОТОМ head.store(h + 1, RELEASE).
//  Свой индекс каждая сторона может читать с RELAXED — его пишет только она.
//
//  Команды несут ВРЕМЯ в сэмплах. Аудиопоток применяет команду ровно
//  на нужном сэмпле, а не «когда дошла» — так звук не «дрожит» вместе
//  с частотой кадров игры (sample-accurate scheduling). Бонус: результат
//  микширования не зависит от того, как потоки поделили процессор, —
//  поэтому эта программа детерминирована, хотя потоков два.
//
//  ЗАДАЧА: реализуйте CommandQueue.push и CommandQueue.pop.
//
import std::io, std::thread, std::atomic;

const int QCAP = 8;             // маленькая, чтобы очередь переполнялась
const int BLOCK = 64;           // кадров в аудиоблоке
const int BLOCKS = 40;
const int GAME_FRAME = 100;     // сэмплов на кадр игры (не кратно BLOCK!)
const int NUM_VOICES = 4;

enum CmdType : char
{
    PLAY,
    STOP,
    VOLUME,
}

struct Command
{
    CmdType type;
    int voice;
    int value;     // PLAY: период в сэмплах; VOLUME: амплитуда
    uint time;     // абсолютное время в сэмплах
}

struct CommandQueue
{
    Command[QCAP] buf;
    Atomic{uint} head;   // пишет только потребитель
    Atomic{uint} tail;   // пишет только производитель
}

fn bool CommandQueue.push(&self, Command c)
{
    uint t = self.tail.load(RELAXED);
    uint h = self.head.load(ACQUIRE);
    if (t - h == (uint)QCAP) return false;
    self.buf[t % QCAP] = c;
    self.tail.store(t + 1, RELEASE);
    return true;
}

fn bool CommandQueue.pop(&self, Command* out)
{
    uint h = self.head.load(RELAXED);
    uint t = self.tail.load(ACQUIRE);
    if (h == t) return false;
    *out = self.buf[h % QCAP];
    self.head.store(h + 1, RELEASE);
    return true;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

struct Osc
{
    bool on;
    int period;
    int amp;
    int phase;
}

struct Shared
{
    CommandQueue q;
    Atomic{uint} published;   // игра обещает: все команды с time < published уже в очереди
    int[BLOCK * BLOCKS] output;
    int applied;
}

// Аудиопоток: без локов и аллокаций. Ждёт (yield), только если игра
// ещё не «опубликовала» команды для следующего блока — в настоящем
// движке на этом месте был бы просто следующий колбэк устройства.
fn int audio_thread(void* arg)
{
    Shared* s = arg;
    Osc[NUM_VOICES] osc;
    Command[64] pending;     // фиксированный массив, никаких аллокаций
    int npending = 0;
    for (int b = 0; b < BLOCKS; b++)
    {
        uint block_start = (uint)(b * BLOCK);
        uint block_end = block_start + BLOCK;
        while (s.published.load(ACQUIRE) < block_end) thread::yield();
        Command c;
        while (s.q.pop(&c)) pending[npending++] = c;
        for (uint t = block_start; t < block_end; t++)
        {
            // применить все команды, чьё время наступило
            int k = 0;
            while (k < npending && pending[k].time <= t)
            {
                Command* cmd = &pending[k++];
                Osc* o = &osc[cmd.voice];
                switch (cmd.type)
                {
                    case PLAY: *o = { .on = true, .period = cmd.value, .amp = 1000 };
                    case STOP: o.on = false;
                    case VOLUME: o.amp = cmd.value;
                }
                s.applied++;
            }
            if (k > 0)
            {
                for (int m = k; m < npending; m++) pending[m - k] = pending[m];
                npending -= k;
            }
            int mix = 0;
            foreach (&o : osc)
            {
                if (!o.on) continue;
                mix += o.phase < o.period / 2 ? o.amp : -o.amp;
                o.phase = (o.phase + 1) % o.period;
            }
            s.output[t] = mix;
        }
    }
    return 0;
}

fn void game_push(Shared* s, Command c)
{
    // очередь полна — ждём, пока аудиопоток разгребёт (игре можно ждать)
    while (!s.q.push(c)) thread::yield();
}

fn void main()
{
    // 1. однопоточная самопроверка очереди
    CommandQueue tq;
    Command c;
    assert(!tq.pop(&c), "пустая очередь");
    for (int i = 0; i < QCAP; i++) assert(tq.push({ .voice = i }), "должно влезать QCAP команд");
    assert(!tq.push({}), "полная очередь должна отказывать");
    for (int i = 0; i < 3; i++) { assert(tq.pop(&c) && c.voice == i, "FIFO"); }
    for (int i = 0; i < 3; i++) assert(tq.push({ .voice = 100 + i }), "кольцо: место освободилось");
    int n = 0;
    while (tq.pop(&c)) n++;
    assert(n == QCAP && c.voice == 102);
    io::printn("queue: ok");

    // 2. два потока
    Shared* s = mem::new(Shared);
    defer free(s);
    Thread audio;
    audio.create(&audio_thread, s)!!;

    int sent = 0;
    for (int frame = 0; frame * GAME_FRAME < BLOCK * BLOCKS; frame++)
    {
        uint t0 = (uint)(frame * GAME_FRAME);
        int v = frame % NUM_VOICES;
        switch (frame % 5)
        {
            case 0: game_push(s, { PLAY, v, 8 + 2 * v, t0 + 7 }); sent++;
            case 1: game_push(s, { VOLUME, v, 400 + 50 * frame, t0 + 33 }); sent++;
            case 2:
                game_push(s, { PLAY, (v + 1) % NUM_VOICES, 12, t0 + 1 });
                game_push(s, { STOP, v, 0, t0 + 50 });
                sent += 2;
            case 3: // в этот кадр игра ничего не шлёт
                break;
            case 4: game_push(s, { STOP, (v + 2) % NUM_VOICES, 0, t0 + 99 }); sent++;
        }
        s.published.store(t0 + GAME_FRAME, RELEASE);
    }
    s.published.store(uint::max, RELEASE);
    audio.join()!!;

    uint h = 2166136261;
    int peak = 0;
    foreach (x : s.output)
    {
        h = (h ^ (uint)x) * 16777619;
        if (x > peak) peak = x;
    }
    assert(s.applied == sent, "аудиопоток должен применить все команды");
    io::printfn("commands sent=%d applied=%d", sent, s.applied);
    io::printfn("samples=%d peak=%d checksum=%08x", BLOCK * BLOCKS, peak, h);
}
