// ---------------------------------------------------------------------
//  mini::events — двойная буферизация событий (глава 06).
//
//      тик N:  physics --push--> [write]      game <--read-- [read]
//      swap(): write и read меняются местами, новый write очищается
//
//  Производитель и потребитель не мешают друг другу, порядок событий
//  стабилен, а событие живёт ровно один тик — никаких «вечных» событий,
//  которые забыли обработать.
// ---------------------------------------------------------------------
module mini::events;

const int MAX_EVENTS = 128;

struct CollisionEvent
{
    uint a;     // индекс сущности, a < b
    uint b;
}

struct EventQueue
{
    CollisionEvent[MAX_EVENTS][2] buf;
    int[2] count;
    int write;       // в какой буфер пишем
    int dropped;     // не влезло — считаем, но не падаем
}

fn void EventQueue.push(&self, CollisionEvent ev)
{
    // TODO: в буфер write; переполнение — dropped++
    (void)ev;
}

<* События, опубликованные последним swap(). *>
fn CollisionEvent[] EventQueue.read(&self)
{
    int r = 1 - self.write;
    return self.buf[r][:self.count[r]];
}

<* Ещё не опубликованные события (то, что накопилось в write). *>
fn CollisionEvent[] EventQueue.pending(&self) => self.buf[self.write][:self.count[self.write]];

fn void EventQueue.swap(&self)
{
    // TODO: поменять буферы, очистить НОВЫЙ буфер записи
}
