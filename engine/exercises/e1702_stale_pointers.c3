// =====================================================================
//  e1702 · Что ломается при перезагрузке: указатели в код модуля
// =====================================================================
//
//  Память игры переживает перезагрузку, а КОД — нет. После dlclose()
//  старой библиотеки её страницы памяти выгружаются, и любой адрес
//  внутри неё становится висячим:
//
//      GameMemory (живёт у хоста)            game_v1.so  (выгружена!)
//      +------------------------+            +-------------------+
//      | entity[0].think = 0x7f.|----------->|  ??? (unmapped)   |
//      | entity[1].think = 0x7f.|----------->|                   |
//      +------------------------+            +-------------------+
//                                            game_v2.so (новая, по ДРУГОМУ адресу)
//
//  Что указывает внутрь модуля и потому умирает при перезагрузке:
//    * указатели на функции (колбэки, «think»-функции сущностей);
//    * таблицы виртуальных методов / интерфейсы (@dynamic в C3!);
//    * указатели на строковые литералы и глобальные константы модуля
//      (String name = "goblin" хранит адрес ВНУТРИ .so);
//    * глобальные переменные модуля — новая копия начинает с нуля.
//
//  Лекарство — хранить в постоянной памяти только ДАННЫЕ: вместо
//  указателя на функцию — её идентификатор (enum/индекс), а адрес
//  находить каждый раз через таблицу ТЕКУЩЕГО модуля. Это та же идея,
//  что хендлы вместо указателей (глава 03), только для кода.
//
//  В этой программе выгрузку модуля имитирует флаг `loaded`: функция
//  выгруженной сборки при вызове падает (как настоящий segfault).
//
//  ЗАДАЧА: сейчас сущности хранят указатель на функцию (`think`).
//  Перепишите хранение на идентификатор поведения: поле `behavior`
//  уже есть, функции spawn и update_entities — помечены TODO.
//
import std::io;

enum Behavior : char
{
    IDLE,
    WANDER,
    CHASE,
}

alias ThinkFn = fn void(Entity*);

struct Entity
{
    int x;
    Behavior behavior;
    ThinkFn think;       // <- опасно: адрес внутри модуля
}

struct GameModule
{
    String name;
    bool* loaded;
    ThinkFn[Behavior::len] behaviors;   // таблица поведения ЭТОЙ сборки
}

// --- сборка v1
bool g_v1_loaded;
fn void v1_check() { assert(g_v1_loaded, "SEGFAULT: вызов кода из выгруженной библиотеки v1"); }
fn void v1_idle(Entity* e) { v1_check(); }
fn void v1_wander(Entity* e) { v1_check(); e.x += 1; }
fn void v1_chase(Entity* e) { v1_check(); e.x += 2; }

// --- сборка v2: поведение исправлено, CHASE стал быстрее
bool g_v2_loaded;
fn void v2_check() { assert(g_v2_loaded, "SEGFAULT: вызов кода из выгруженной библиотеки v2"); }
fn void v2_idle(Entity* e) { v2_check(); }
fn void v2_wander(Entity* e) { v2_check(); e.x -= 1; }
fn void v2_chase(Entity* e) { v2_check(); e.x += 5; }

fn GameModule load_v1() { g_v1_loaded = true; return { "v1", &g_v1_loaded, { &v1_idle, &v1_wander, &v1_chase } }; }
fn GameModule load_v2() { g_v2_loaded = true; return { "v2", &g_v2_loaded, { &v2_idle, &v2_wander, &v2_chase } }; }
fn void unload(GameModule* m) { *m.loaded = false; }

fn Entity spawn(GameModule* mod, int x, Behavior b)
{
    // TODO: не сохраняйте указатель на функцию модуля
    return { .x = x, .behavior = b, .think = mod.behaviors[b] };
}

fn void update_entities(GameModule* mod, Entity[] entities)
{
    foreach (&e : entities)
    {
        // TODO: найдите функцию через таблицу ТЕКУЩЕГО модуля
        e.think(e);
    }
}

fn void main()
{
    Entity[4] world;
    GameModule mod = load_v1();
    world[0] = spawn(&mod, 0, IDLE);
    world[1] = spawn(&mod, 10, WANDER);
    world[2] = spawn(&mod, 20, CHASE);
    world[3] = spawn(&mod, 30, CHASE);
    for (int i = 0; i < 3; i++) update_entities(&mod, &world);
    io::printfn("%s: %d %d %d %d", mod.name, world[0].x, world[1].x, world[2].x, world[3].x);

    // горячая перезагрузка: v1 выгружается, v2 загружается
    unload(&mod);
    mod = load_v2();
    for (int i = 0; i < 3; i++) update_entities(&mod, &world);
    io::printfn("%s: %d %d %d %d", mod.name, world[0].x, world[1].x, world[2].x, world[3].x);
    assert(world[1].x == 10 && world[2].x == 41, "сущности должны использовать код v2");
    io::printn("reload survived");
}
