// =====================================================================
//  060 · Подтипы: inline-член структуры
// =====================================================================
//
//  В C3 нет классов и наследования, но есть простой и честный механизм
//  «встраивания» — первый член структуры можно пометить `inline`:
//
//      struct Entity { Vec2 pos; String name; }
//
//      struct Player
//      {
//          inline Entity base;   // Player «является» Entity
//          int hp;
//      }
//
//  Что это даёт:
//    * поля и методы Entity доступны прямо на Player:
//          p.name, p.pos.x, p.move(1, 2)   // то же, что p.base.name ...
//    * `Player*` неявно приводится к `Entity*`, а `Player` к `Entity`
//      (копируется только часть base) — Player можно передать в любую
//      функцию, которая ждёт Entity;
//    * `@dynamic`-методы (интерфейсы, 059) тоже наследуются.
//
//  Раскладка памяти — как в C: `base` лежит в начале Player, поэтому
//  указатель на Player — это и указатель на его Entity. Никаких скрытых
//  vtable. Цепочки работают: Boss { inline Player player; } — это и
//  Player, и Entity.
//
//  Инициализация — как у обычного вложенного поля, по имени члена:
//      Player p = { .base = { .name = "hero" }, .hp = 100 };
//
//  Это не настоящее ООП-наследование: нет переопределения методов (если
//  у Player объявить свой `move`, он просто скроет Entity.move для
//  Player, но функция, получившая Entity*, вызовет Entity.move).
//
//  Ловушка с `any`: в `switch (x.type)` подтип совпадает с `case`
//  родителя! Если `case Entity:` стоит раньше `case Player:`, то Player
//  попадёт в ветку Entity. Поэтому в таком switch более конкретные
//  типы ставят ПЕРВЫМИ.
//
//  ЗАДАЧА: сделайте Player и Boss подтипами (inline) и упорядочьте
//  case'ы в `kind_of`. Ожидаемый вывод:
//      hero at (4, 6)
//      dragon at (10, 0)
//      hero: player with 100 hp
//      dragon: boss in phase 2
//      rock: plain entity
//
import std::io;

struct Vec2
{
    int x, y;
}

struct Entity
{
    Vec2 pos;
    String name;
}

fn void Entity.move(&self, int dx, int dy)
{
    self.pos.x += dx;
    self.pos.y += dy;
}

fn void print_entity(Entity* e) => io::printfn("%s at (%d, %d)", e.name, e.pos.x, e.pos.y);

struct Player
{
    Entity base;            // TODO: Player должен «быть» Entity
    int hp;
}

struct Boss
{
    Player player;
    int phase;
}

fn String kind_of(any x)
{
    switch (x.type)   // <- порядок case'ов имеет значение!
    {
        case Entity:
            return string::tformat("%s: plain entity", ((Entity*)x).name);
        case Player:
            return string::tformat("%s: player with %d hp", ((Player*)x).name, ((Player*)x).hp);
        case Boss:
            return string::tformat("%s: boss in phase %d", ((Boss*)x).name, ((Boss*)x).phase);
        default:
            return "???";
    }
}

fn void main()
{
    Player p = { .base = { .pos = { 1, 2 }, .name = "hero" }, .hp = 100 };
    p.move(3, 4);            // метод Entity прямо на Player
    print_entity(&p);        // Player* -> Entity*

    Boss b = { .player = { .base = { .name = "dragon" }, .hp = 500 }, .phase = 2 };
    b.move(10, 0);
    print_entity(&b);        // Boss* -> Entity* через два уровня
    assert(b.hp == 500);     // поле Player прямо на Boss

    Entity rock = { .name = "rock" };
    any[] all = { &p, &b, &rock };
    foreach (x : all) io::printn(kind_of(x));
}
