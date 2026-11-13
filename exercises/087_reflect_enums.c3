// =====================================================================
//  087 · Рефлексия enum'ов и методов
// =====================================================================
//
//  ENUM. Часть свойств вы видели в 026–027, теперь — полная картина:
//
//      Planet::len            // количество значений
//      Planet::values         // все значения (массив, доступен в рантайме)
//      Planet::names          // их имена-строки: { "MERCURY", ... }
//      Planet::from_ordinal(i)   // значение по номеру
//      Planet::members        // ассоциированные поля (mass, moons):
//                             //   $m.name, $m.type — как у структур
//      Planet::lookup_field(moons, 2)   // значение по первому совпадению
//                                       // ассоциированного поля (Optional)
//      p.ordinal, p.description         // номер и имя конкретного значения
//
//  Обратите внимание на `::` для свойств ТИПА и `.` для значений:
//  `Dir::from_ordinal(1)`, но `Dir.NORTH`. Запись `Dir.from_ordinal`
//  в 0.8.5 — ошибка.
//
//  Типичная задача — разбор строки в enum. В C это ручной `strcmp` по
//  каждому имени (и таблица, которую забывают обновить). В C3 имена
//  всегда под рукой: пройдитесь по `$Enum::names`.
//
//  МЕТОДЫ. `Type::methods` — compile-time список ИМЁН методов типа
//  (строк). Вместе с `$eval` это позволяет вызывать метод по имени:
//
//      $foreach $m : Robot::methods:
//          $if $m.len > 4 &&& $m[0..3] == "cmd_":
//              r.$eval($m)();          // r.cmd_left(), r.cmd_right()...
//          $endif
//      $endforeach
//
//  Compile-time строки можно сравнивать, брать `.len` и срезы — так
//  выбираются методы по префиксу. Оператор `&&&` нужен, чтобы срез
//  `$m[0..3]` даже не рассматривался для коротких имён.
//
//  Предупреждение из документации: методы регистрируются ПОСЛЕ типов,
//  поэтому на верхнем уровне (например, в `$assert` вне функции) список
//  может быть неполным. Внутри функций и макросов он надёжен. Порядок —
//  порядок объявления.
//
//  Это основа «автоматической регистрации»: консольные команды, тесты,
//  обработчики событий — добавил метод с нужным префиксом, и он
//  подхватился сам, без ручных таблиц.
//
//  ЗАДАЧА:
//    1. Реализуйте `@parse_enum($Enum, s)`: вернуть значение enum, имя
//       которого равно s, или ошибку NOT_FOUND~.
//    2. Допишите `run_all_commands`: вызвать у робота все методы, имя
//       которых начинается с "cmd_", и после каждого напечатать
//       "<имя метода> -> x=<x>".
//
module enum_demo;
import std::io;

excuse NOT_FOUND;

enum Planet : (double mass, int moons)
{
    MERCURY { 0.33, 0 },
    EARTH   { 5.97, 1 },
    MARS    { 0.642, 2 },
}

enum Dir { NORTH, EAST, SOUTH, WEST }

fn Dir Dir.turn_right(self) => Dir::from_ordinal((self.ordinal + 1) % (int)Dir::len);

struct Robot
{
    int x;
}

fn void Robot.cmd_left(&self) => self.x -= 1;
fn void Robot.cmd_jump(&self) => self.x += 10;
fn void Robot.reset(&self) => self.x = 0;
fn void Robot.cmd_right(&self) => self.x += 1;

macro @parse_enum($Enum, String s)
{
    // TODO: найдите s среди $Enum::names и верните соответствующее значение.
    return $Enum::from_ordinal(0);
}

fn void run_all_commands(Robot* r)
{
    // TODO: $foreach по Robot::methods, вызвать все cmd_* методы
}

fn void main()
{
    io::printfn("%d planets: %s", Planet::len, Planet::names);
    $foreach $m : Planet::members:
        io::printfn("associated: %s (%s)", $m.name, $m.type.name);
    $endforeach
    foreach (p : Planet::values) io::printfn("  %s mass=%.2f moons=%d", p, p.mass, p.moons);
    io::printfn("two moons: %s", Planet::lookup_field(moons, 2)!!);

    Dir d = NORTH;
    for (int i = 0; i < 5; i++)
    {
        io::printf("%s ", d);
        d = d.turn_right();
    }
    io::printn();

    Dir? south = @parse_enum(Dir, "SOUTH");
    assert(south!! == Dir.SOUTH);
    Planet? earth = @parse_enum(Planet, "EARTH");
    assert(earth!!.moons == 1);
    Dir? bad = @parse_enum(Dir, "UP");
    if (catch err = bad) io::printfn("parse UP: %s", err);
    io::printfn("parse SOUTH: %s, ordinal %d", south!!, south!!.ordinal);

    Robot r;
    run_all_commands(&r);
    assert(r.x == 10);
}
