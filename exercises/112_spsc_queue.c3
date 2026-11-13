// =====================================================================
//  112 · Lock-free SPSC-очередь на атомиках
// =====================================================================
//
//  SPSC = Single Producer, Single Consumer: ровно один поток пишет,
//  ровно один читает. Самая частая схема межпоточного обмена в движках:
//  игровой поток -> поток рендера (команды отрисовки), декодер ->
//  аудио-колбэк, сетевой поток -> игровой (пакеты), логгер. Аудио-
//  колбэк вообще нельзя блокировать мьютексом: если ОС усыпит поток,
//  держащий мьютекс, звук «заикнётся» (priority inversion). Поэтому —
//  lock-free.
//
//  ИДЕЯ
//  ----
//  Берём кольцевой буфер из упражнения 111 с монотонными счётчиками.
//  Производитель — единственный, кто ПИШЕТ tail; потребитель —
//  единственный, кто ПИШЕТ head. Каждый лишь ЧИТАЕТ счётчик другого.
//  Нет записи в одну переменную из двух потоков => не нужен ни мьютекс,
//  ни CAS — хватает атомарных load/store с правильным упорядочиванием.
//
//  УПОРЯДОЧИВАНИЕ ПАМЯТИ — суть упражнения
//  ---------------------------------------
//  Процессор и компилятор переставляют обычные чтения/записи. Если
//  производитель сделает `tail = t + 1` раньше, чем запись самого
//  элемента станет видна другому ядру, потребитель прочтёт мусор.
//  Пара release/acquire решает это:
//
//    производитель:                       потребитель:
//      items[t & mask] = v;                 t = tail.load(ACQUIRE);
//      tail.store(t + 1, RELEASE);  ---->   if (h != t) v = items[h & mask];
//
//  RELEASE-запись гарантирует: всё, что поток записал ДО неё, видно
//  любому, кто прочитал это значение ACQUIRE-чтением. Симметрично для
//  head: потребитель публикует head с RELEASE после того, как ЗАБРАЛ
//  элемент, а производитель читает head с ACQUIRE перед тем, как
//  перезаписать ячейку. Свой собственный счётчик каждый поток может
//  читать RELAXED — его никто другой не меняет.
//  На x86 (TSO) acquire/release почти бесплатны (обычные mov), на ARM
//  это ldar/stlr. SEQ_CONSISTENT тоже был бы корректен, но дороже
//  (на x86 store превращается в xchg/mfence).
//
//  FALSE SHARING
//  -------------
//  head и tail пишут разные ядра. Если они лежат в одной 64-байтной
//  кеш-линии, протокол когерентности (MESI) будет гонять линию между
//  ядрами при каждой операции — «ложное разделение», замедление в разы.
//  Лечится выравниванием каждого счётчика на свою кеш-линию:
//  `@align(64)` у поля. Ещё одна оптимизация из реальных реализаций
//  (rigtorp::SPSCQueue, Linux kfifo, LMAX Disruptor): каждый поток
//  держит КЕШИРОВАННУЮ копию чужого счётчика и перечитывает атомик
//  только когда по кешу очередь выглядит полной/пустой.
//
//  ПОДВОДНЫЕ КАМНИ
//  ---------------
//  * Это ТОЛЬКО SPSC. Два производителя сломают всё (оба запишут в
//    одну ячейку). MPMC-очереди устроены гораздо сложнее (Vyukov).
//  * Тесты lock-free кода, проходящие на x86, могут падать на ARM:
//    x86 прощает слабые упорядочивания. Думайте, а не проверяйте.
//  * Активное ожидание (spin) жжёт ядро; при пустой/полной очереди
//    делайте thread::yield() или переходите на ожидание события.
//
//  ЗАДАЧА: реализуйте try_push и try_pop с правильными порядками
//  (Atomic.load/store принимают порядок вторым/третьим аргументом:
//  `x.load(ACQUIRE)`, `x.store(v, RELEASE)`), и выровняйте head/tail по
//  кеш-линиям (см. $assert в main). Затем main прогонит 200 000 чисел
//  через очередь между двумя потоками и проверит порядок и сумму.
//
import std::io;
import std::thread;
import std::atomic;

const CACHE_LINE = 64;

struct SpscQueue <Type, CAP>
{
    // TODO: разнесите счётчики по разным кеш-линиям: атрибут @align(CACHE_LINE) у полей.
    Atomic{uint} head;   // пишет только потребитель
    Atomic{uint} tail;   // пишет только производитель
    Type[CAP] items;
}

fn uint SpscQueue.mask(&self) @inline => (uint)CAP - 1;

// Вызывается только производителем.
fn bool SpscQueue.try_push(&self, Type v)
{
    // TODO:
    //  t = свой tail (RELAXED), h = чужой head (ACQUIRE);
    //  если t - h == CAP — полна, false;
    //  записать элемент, опубликовать tail = t + 1 (RELEASE).
    return false;
}

// Вызывается только потребителем.
fn bool SpscQueue.try_pop(&self, Type* out)
{
    // TODO: зеркально: h — свой (RELAXED), t — чужой (ACQUIRE);
    //       пусто, если h == t; прочитать элемент, затем head = h + 1 (RELEASE).
    return false;
}

// ---------------------------------------------------------------- проверка

struct Msg
{
    uint seq;
    uint payload;
}

alias Queue = SpscQueue{Msg, 1024};

const uint COUNT = 200_000;

fn int producer(void* arg)
{
    Queue* q = arg;
    for (uint i = 1; i <= COUNT; i++)
    {
        Msg m = { i, i * 3 + 1 };
        while (!q.try_push(m)) thread::yield();
    }
    return 0;
}

fn void main()
{
    $assert $reflect(Queue.tail).offset - $reflect(Queue.head).offset >= CACHE_LINE
        : "head and tail share a cache line (false sharing)";

    // --- однопоточные проверки
    SpscQueue{int, 4} small;
    int out;
    assert(!small.try_pop(&out), "empty queue must not pop");
    for (int i = 0; i < 4; i++) assert(small.try_push(i), "push %d failed", i);
    assert(!small.try_push(99), "full queue must reject push");
    assert(small.try_pop(&out) && out == 0);
    assert(small.try_push(4));
    for (int i = 1; i <= 4; i++) assert(small.try_pop(&out) && out == i);
    assert(!small.try_pop(&out));
    io::printn("single-thread checks passed");

    // --- два потока
    // Тип с выравниванием 64 > стандартного 16: обычный mem::new откажется
    // (контракт), нужен new_aligned + free_aligned.
    Queue* q = mem::new_aligned(Queue);
    defer free_aligned(q);
    Thread t;
    t.create(&producer, q)!!;

    uint expected = 1;
    ulong sum = 0;
    while (expected <= COUNT)
    {
        Msg m;
        if (!q.try_pop(&m))
        {
            thread::yield();
            continue;
        }
        assert(m.seq == expected, "out of order: got %d, expected %d", m.seq, expected);
        assert(m.payload == m.seq * 3 + 1, "torn message %d", m.seq);
        sum += m.payload;
        expected++;
    }
    t.join()!!;
    assert(!q.try_pop(&&(Msg){}), "queue must be empty at the end");
    io::printfn("received %d messages in order, payload sum = %d", COUNT, sum);
}
