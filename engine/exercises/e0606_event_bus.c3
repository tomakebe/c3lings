// =====================================================================
//  E0606 · Шина событий: типизированные каналы, приоритеты, очереди
// =====================================================================
//
//  Сначала прочитайте engine/docs/06_events.md (раздел 8).
//
//  Соберём всё вместе. Шина событий движка — это набор КАНАЛОВ, по
//  одному на тип события. Канал — generic-структура Channel{Type}:
//
//      struct Bus
//      {
//          Channel{InputEvent}  input;
//          Channel{DamageEvent} damage;
//          Channel{SoundEvent}  sound;
//      }
//
//  Типизация даёт то, чего нет у «одного большого union»: обработчик
//  получает `DamageEvent*`, а не «что-то, что надо разобрать по тегу»,
//  и ошибка подписки — это ошибка компиляции.
//
//  Каждый канал умеет две доставки:
//    * send(ev)  — немедленная (E0601): подписчики вызываются сразу;
//    * post(ev)  — отложенная (E0602/E0603): событие ложится в
//                  write-буфер, а flush() в известной точке кадра
//                  меняет буферы и рассылает накопленное.
//
//  И два усложнения из реальной жизни:
//    * ПРИОРИТЕТ: подписчики вызываются по убыванию priority, при
//      равном priority — в порядке подписки (стабильно). Так консоль
//      разработчика видит ввод раньше меню, а меню — раньше игры.
//    * ПОГЛОЩЕНИЕ (consume): обработчик возвращает true — «я обработал,
//      дальше не передавать». Открытое меню съедает ввод, и персонаж
//      не стреляет, пока вы кликаете по кнопкам. Это та же идея, что
//      «input contexts» в главе 10.
//
//  Generic-код в C3 проверяется при инстанцировании: ошибки в методах
//  Channel вы увидите, когда main() использует Channel{InputEvent}.
//
//  ЗАДАЧА: реализуйте методы Channel, помеченные TODO.
//
import std::io;
import std::collections::list;

alias Handler <Type> = fn bool(void* ctx, Type* ev);

struct HandlerSlot <Type>
{
    Handler{Type} handler;
    void* ctx;
    int priority;
    uint id;
}

struct Channel <Type>
{
    List{HandlerSlot{Type}} handlers;   // по убыванию priority, стабильно
    List{Type}[2] queue;                 // двойной буфер для post/flush
    int write;
    uint next_id;
    int consumed;                        // сколько событий было поглощено
}

fn void Channel.free(&self)
{
    self.handlers.free();
    self.queue[0].free();
    self.queue[1].free();
}

<*
 Вставляет обработчик ПЕРЕД первым обработчиком с меньшим priority
 (то есть после всех с priority >= данного). Возвращает id (1, 2, ...).
*>
fn uint Channel.subscribe(&self, Handler{Type} h, void* ctx, int priority)
{
    // TODO
    return 0;
}

fn void Channel.unsubscribe(&self, uint id)
{
    // TODO
}

<* Немедленная рассылка. true, если какой-то обработчик поглотил событие. *>
fn bool Channel.send(&self, Type ev)
{
    // TODO
    return false;
}

fn void Channel.post(&self, Type ev)
{
    // TODO
}

<* Меняет буферы и рассылает всё, что было опубликовано до вызова. *>
fn int Channel.flush(&self)
{
    // TODO
    return 0;
}

// ---------------------------------------------------------------------
// Игра. Ничего ниже менять не нужно.
// ---------------------------------------------------------------------

enum Key : char { FIRE, MENU, JUMP }

struct InputEvent  { Key key; }
struct DamageEvent { int target; int amount; }
struct SoundEvent  { char id; }

struct Bus
{
    Channel{InputEvent} input;
    Channel{DamageEvent} damage;
    Channel{SoundEvent} sound;
}

char[256] g_log;
int g_log_len;
fn void say(String s)
{
    foreach (c : s) if (g_log_len < 256) g_log[g_log_len++] = c;
}

struct Console { int seen; }
struct Menu { bool open; Bus* bus; }
struct Player { Bus* bus; int target; int shots; int jumps; }
struct Health { int[2] hp; Bus* bus; }
struct Audio { char[16] played; int count; }

fn bool console_on_input(void* ctx, InputEvent* ev)
{
    Console* c = ctx;
    c.seen++;
    return false;              // только смотрит
}

fn bool menu_on_input(void* ctx, InputEvent* ev)
{
    Menu* m = ctx;
    if (ev.key == MENU)
    {
        m.open = !m.open;
        say(m.open ? "[menu+]" : "[menu-]");
        m.bus.sound.send({ 'm' });
        return true;
    }
    if (m.open)
    {
        say("[eaten]");
        return true;           // меню открыто — игра ввод не видит
    }
    return false;
}

fn bool player_on_input(void* ctx, InputEvent* ev)
{
    Player* p = ctx;
    switch (ev.key)
    {
        case FIRE:
            p.shots++;
            say("[fire]");
            p.bus.damage.post({ p.target, 40 });   // урон применится в конце кадра
            p.bus.sound.send({ 'f' });
        case JUMP:
            p.jumps++;
            say("[jump]");
        default:
            break;
    }
    return true;
}

fn bool health_on_damage(void* ctx, DamageEvent* ev)
{
    Health* h = ctx;
    if (h.hp[ev.target] <= 0) return false;
    h.hp[ev.target] -= ev.amount;
    say("[hit]");
    if (h.hp[ev.target] <= 0)
    {
        say("[dead]");
        h.bus.sound.post({ 'd' });   // звук смерти — в очередь
    }
    return false;
}

fn bool audio_on_sound(void* ctx, SoundEvent* ev)
{
    Audio* a = ctx;
    if (a.count < 16) a.played[a.count++] = ev.id;
    return false;
}

fn void main()
{
    Bus bus;
    defer { bus.input.free(); bus.damage.free(); bus.sound.free(); }

    Console console;
    Menu menu = { .bus = &bus };
    Player player = { .bus = &bus, .target = 1 };
    Health health = { .hp = { 100, 100 }, .bus = &bus };
    Audio audio;

    // Подписываемся НЕ в порядке приоритета — канал обязан упорядочить.
    uint pid = bus.input.subscribe(&player_on_input, &player, 0);
    uint mid = bus.input.subscribe(&menu_on_input, &menu, 100);
    bus.input.subscribe(&console_on_input, &console, 1000);
    bus.damage.subscribe(&health_on_damage, &health, 0);
    bus.sound.subscribe(&audio_on_sound, &audio, 0);
    assert(pid == 1 && mid == 2);
    assert(bus.input.handlers[0].priority == 1000 && bus.input.handlers[2].priority == 0,
           "handlers must be sorted by descending priority");

    // Стабильность при равном приоритете.
    Channel{InputEvent} tmp;
    defer tmp.free();
    uint t1 = tmp.subscribe(&console_on_input, &console, 5);
    uint t2 = tmp.subscribe(&console_on_input, &console, 5);
    uint t3 = tmp.subscribe(&console_on_input, &console, 7);
    assert(tmp.handlers[0].id == t3 && tmp.handlers[1].id == t1 && tmp.handlers[2].id == t2,
           "equal priorities must keep subscription order");
    tmp.unsubscribe(t1);
    assert(tmp.handlers.len() == 2 && tmp.handlers[1].id == t2);

    Key[][] frames = {
        { FIRE, JUMP },
        { MENU, FIRE, JUMP },
        { MENU, FIRE },
        { FIRE },
        {},
    };
    foreach (i, keys : frames)
    {
        g_log_len = 0;
        foreach (k : keys) bus.input.send({ k });
        int dmg = bus.damage.flush();
        int snd = bus.sound.flush();
        io::printfn("frame %d: %s damage=%d sounds=%d", i, (String)g_log[:g_log_len], dmg, snd);
    }

    assert(console.seen == 8, "console must see every input");
    assert(player.shots == 3 && player.jumps == 1);
    assert(health.hp[1] == -20 && health.hp[0] == 100);
    assert(bus.input.consumed == 8, "every input is consumed by menu or player");
    assert((String)audio.played[:audio.count] == "fmmffd", "wrong sound order");

    bus.input.unsubscribe(mid);
    bus.input.send({ MENU });
    assert(!menu.open, "unsubscribed menu must not react");

    io::printfn("sounds: %s", (String)audio.played[:audio.count]);
    io::printn("event bus: all checks passed");
}
