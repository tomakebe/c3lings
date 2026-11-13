// =====================================================================
//  E0602 · Очередь событий: tagged union + кольцевой буфер
// =====================================================================
//
//  Сначала прочитайте engine/docs/06_events.md (разделы 4–5).
//
//  Немедленная доставка (E0601) связывает отправителя и получателя во
//  ВРЕМЕНИ: обработчик выполняется посреди кода отправителя, с его
//  кешем, его блокировками и его недоделанным состоянием. Очередь
//  разрывает эту связь: отправитель только КЛАДЁТ событие, а система
//  потом, в известной точке кадра, РАЗБИРАЕТ очередь.
//
//  Событие в очереди должно быть значением фиксированного размера,
//  без указателей на чужие объекты (к моменту обработки объект может
//  умереть). Классическая форма — tagged union:
//
//      struct Event
//      {
//          EventKind kind;        // тег
//          uint entity;           // общее поле (id/handle, не указатель!)
//          union                  // полезная нагрузка — по тегу
//          {
//              DamageData damage;
//              PickupData pickup;
//          }
//      }
//
//  Все события одного размера (размер самого большого варианта), лежат
//  подряд в памяти — очередь получается простым массивом.
//
//  Очередь — кольцевой буфер фиксированной ёмкости:
//
//      head ──► [ e2 ][ e3 ][    ][    ][ e0 ][ e1 ]
//                              ▲ tail = (head + count) % CAP
//
//  push пишет в позицию (head + count) % CAP и увеличивает count;
//  pop читает из head, сдвигает head = (head + 1) % CAP, уменьшает
//  count. Никаких аллокаций в кадре, никаких сдвигов памяти.
//
//  Что делать при переполнении — архитектурное решение. Здесь —
//  политика «отбросить новое и посчитать»: push возвращает false, а
//  счётчик `dropped` растёт (в реальном движке — warning в лог и
//  метрика в профайлере).
//
//  ЗАДАЧА: реализуйте EventQueue.push / EventQueue.pop и функцию
//  dispatch(), которая разбирает очередь и применяет события к миру
//  (по `switch (ev.kind)`).
//
import std::io;

enum EventKind : char
{
    DAMAGE,
    HEAL,
    PICKUP,
    DIED,
}

struct DamageData { int amount; uint source; }
struct PickupData { int item; int count; }

struct Event
{
    EventKind kind;
    uint entity;
    union
    {
        DamageData damage;
        int heal;
        PickupData pickup;
    }
}

const int QUEUE_CAP = 8;

struct EventQueue
{
    Event[QUEUE_CAP] items;
    int head;
    int count;
    int dropped;
}

<* @return "false, если очередь полна (событие отброшено и посчитано)" *>
fn bool EventQueue.push(&self, Event ev)
{
    // TODO
    return false;
}

<* @return "false, если очередь пуста" *>
fn bool EventQueue.pop(&self, Event* out)
{
    // TODO
    return false;
}

// ---------------------------------------------------------------------
// «Мир»: три сущности со здоровьем и инвентарём.
// ---------------------------------------------------------------------

struct Actor
{
    int hp;
    int max_hp;
    int[4] items;
    bool dead;
}

struct World
{
    Actor[3] actors;
    int deaths_reported;
}

<*
 Разбирает очередь до конца и применяет события к миру.
   DAMAGE: hp -= amount (не ниже 0). Если hp стал 0 и актёр ещё не
           мёртв — пометить dead и положить в ЭТУ ЖЕ очередь событие
           DIED для этой сущности (оно будет обработано в этом же
           вызове, ведь мы разбираем очередь до пустоты).
   HEAL:   hp += heal (не выше max_hp), мёртвых не лечим.
   PICKUP: items[item] += count.
   DIED:   world.deaths_reported++.
 Возвращает количество обработанных событий.
*>
fn int dispatch(EventQueue* q, World* w)
{
    // TODO
    return 0;
}

fn void main()
{
    io::printfn("sizeof(Event) = %d", Event::size);

    // 1. Кольцо: заполняем, переполняем, частично читаем, заворачиваемся.
    EventQueue q;
    for (int i = 0; i < 10; i++)
    {
        q.push({ .kind = HEAL, .entity = 0, .heal = i });
    }
    assert(q.count == QUEUE_CAP && q.dropped == 2, "queue must hold 8 and drop 2");
    Event ev;
    for (int i = 0; i < 5; i++)
    {
        assert(q.pop(&ev));
        assert(ev.heal == i, "FIFO order broken");
    }
    for (int i = 10; i < 15; i++) assert(q.push({ .kind = HEAL, .heal = i }));
    assert(q.head == 5 && q.count == 8, "push must wrap around the ring");
    int[8] expect = { 5, 6, 7, 10, 11, 12, 13, 14 };
    foreach (e : expect)
    {
        assert(q.pop(&ev) && ev.heal == e, "FIFO across the wrap point broken");
    }
    assert(!q.pop(&ev), "empty queue must return false");

    // 2. Кадр игры: системы кладут события, в конце кадра — dispatch.
    World w;
    foreach (&a : w.actors) { a.hp = 50; a.max_hp = 50; }
    EventQueue frame;
    frame.push({ .kind = DAMAGE, .entity = 1, .damage = { 30, 0 } });
    frame.push({ .kind = PICKUP, .entity = 0, .pickup = { .item = 2, .count = 3 } });
    frame.push({ .kind = DAMAGE, .entity = 1, .damage = { 30, 2 } });   // убивает 1
    frame.push({ .kind = HEAL, .entity = 1, .heal = 100 });             // поздно
    frame.push({ .kind = DAMAGE, .entity = 2, .damage = { 10, 0 } });
    frame.push({ .kind = HEAL, .entity = 2, .heal = 100 });
    frame.push({ .kind = DAMAGE, .entity = 1, .damage = { 5, 0 } });    // по трупу
    int n = dispatch(&frame, &w);
    assert(n == 8, "7 events + 1 DIED produced during dispatch");
    assert(w.actors[0].items[2] == 3);
    assert(w.actors[1].hp == 0 && w.actors[1].dead);
    assert(w.actors[2].hp == 50, "heal is clamped to max_hp");
    assert(w.deaths_reported == 1, "DIED must be reported exactly once");
    assert(frame.count == 0);

    io::printfn("ring: dropped=%d head=%d", q.dropped, q.head);
    io::printfn("frame: processed=%d hp=[%d %d %d] deaths=%d",
                n, w.actors[0].hp, w.actors[1].hp, w.actors[2].hp, w.deaths_reported);
    io::printn("event queue: all checks passed");
}
