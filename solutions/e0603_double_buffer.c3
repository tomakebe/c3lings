// =====================================================================
//  E0603 · Двойная буферизация событий
// =====================================================================
//
//  Сначала прочитайте engine/docs/06_events.md (раздел 5).
//
//  В E0602 dispatch() разбирал очередь «до пустоты», а обработчики
//  клали новые события в ту же очередь. Это удобно, но опасно:
//
//    * цепная реакция (бочка взрывает бочку, которая взрывает бочку…)
//      целиком выполняется в ОДНОМ кадре — непредсказуемый пик работы;
//    * два обработчика, отвечающие друг другу (PING -> PONG -> PING…),
//      зацикливают кадр навсегда;
//    * порядок обработки зависит от того, кто и когда положил событие
//      посреди разбора.
//
//  Решение — ДВА буфера. Пишем всегда в «write»-буфер. В начале
//  обработки буферы меняются ролями (swap): то, что накопилось за
//  прошлый кадр, становится «read»-буфером, а новый «write» очищается.
//  Всё, что обработчики публикуют во время разбора, попадает в новый
//  write-буфер и будет обработано в СЛЕДУЮЩЕМ кадре.
//
//      кадр N:   post ──► [ write ]          [ read  ] ──► handlers
//                                  \ swap  /
//      кадр N+1: post ──► [ read' ]  ╳     [ write'] ──► handlers
//
//  Это тот же приём, что двойная буферизация кадра в рендере и
//  состояния в симуляциях клеточных автоматов: читаем снимок прошлого,
//  пишем будущее, и никто не видит «полусостояние».
//
//  Цена — задержка на кадр. Поэтому в движках обычно есть и то, и
//  другое: немедленные сигналы для «надо прямо сейчас» и
//  буферизованные очереди для всего остального.
//
//  Буферы здесь — `List{Event}` (растущие массивы). После первых
//  кадров они перестают аллоцировать: clear() не освобождает память.
//
//  ЗАДАЧА: реализуйте
//    * EventBus.post       — добавить событие в write-буфер;
//    * EventBus.swap       — поменять буферы местами, очистить новый
//                            write-буфер, вернуть указатель на read-буфер;
//    * run_frame           — swap + вызвать handle() для каждого события
//                            read-буфера по порядку; вернуть их число.
//
import std::io;
import std::collections::list;

enum EventKind : char
{
    HIT,
    EXPLODE,
    PING,
    PONG,
}

struct Event
{
    EventKind kind;
    int target;
}

struct EventBus
{
    List{Event}[2] bufs;
    int write;
}

fn void EventBus.free(&self)
{
    self.bufs[0].free();
    self.bufs[1].free();
}

fn void EventBus.post(&self, Event ev)
{
    // TODO
    self.bufs[self.write].push(ev);
}

fn List{Event}* EventBus.swap(&self)
{
    // TODO
    int read = self.write;
    self.write ^= 1;
    self.bufs[self.write].clear();
    return &self.bufs[read];
}

// ---------------------------------------------------------------------
// Мир: ряд бочек. Удар снимает 1 hp, бочка с 0 hp взрывается и бьёт
// соседей. Плюс пара «болтунов» PING/PONG.
// ---------------------------------------------------------------------

const int BARRELS = 7;

struct World
{
    int[BARRELS] hp;
    bool[BARRELS] exploded;
    int pings;
    int pongs;
    char[64] log;
    int log_len;
}

fn void World.note(&self, char c)
{
    if (self.log_len < 64) self.log[self.log_len++] = c;
}

fn void handle(World* w, EventBus* bus, Event ev)
{
    switch (ev.kind)
    {
        case HIT:
            if (ev.target < 0 || ev.target >= BARRELS || w.exploded[ev.target]) return;
            w.hp[ev.target]--;
            if (w.hp[ev.target] <= 0) bus.post({ EXPLODE, ev.target });
        case EXPLODE:
            if (w.exploded[ev.target]) return;
            w.exploded[ev.target] = true;
            w.note((char)('0' + ev.target));
            bus.post({ HIT, ev.target - 1 });
            bus.post({ HIT, ev.target + 1 });
        case PING:
            w.pings++;
            bus.post({ PONG, 0 });
        case PONG:
            w.pongs++;
            bus.post({ PING, 0 });
    }
}

<* Обрабатывает события, опубликованные ДО начала этого вызова. *>
fn int run_frame(World* w, EventBus* bus)
{
    // TODO
    List{Event}* read = bus.swap();
    foreach (ev : *read) handle(w, bus, ev);
    return (int)read.len();
}

fn void main()
{
    World w;
    EventBus bus;
    defer bus.free();

    // У крайней левой бочки 2 hp — её одна волна не добьёт.
    w.hp = { 2, 1, 1, 1, 1, 1, 1 };

    bus.post({ HIT, 3 });
    int frame;
    int total;
    while (true)
    {
        w.log_len = 0;
        int n = run_frame(&w, &bus);
        if (n == 0) break;
        frame++;
        total += n;
        io::printfn("frame %d: events=%d exploded=[%s]", frame, n, (String)w.log[:w.log_len]);
        assert(frame < 20, "chain reaction must terminate");
    }
    assert(frame == 9, "the explosion wave must spread one step per two frames");
    assert(!w.exploded[0] && w.hp[0] == 1, "barrel 0 survives with 1 hp");
    for (int i = 1; i < BARRELS; i++) assert(w.exploded[i]);

    // PING/PONG: с одной очередью «до пустоты» это вечный цикл.
    // С двойной буферизацией — ровно одно событие за кадр.
    w.pings = 0;
    w.pongs = 0;
    bus.post({ PING, 0 });
    for (int i = 0; i < 5; i++)
    {
        assert(run_frame(&w, &bus) == 1, "exactly one ping/pong per frame");
    }
    assert(w.pings == 3 && w.pongs == 2);

    io::printfn("chain: frames=%d events=%d", frame, total);
    io::printfn("pingpong: pings=%d pongs=%d", w.pings, w.pongs);
    io::printn("double buffer: all checks passed");
}
