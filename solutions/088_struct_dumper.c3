// =====================================================================
//  088 · Рефлексия на практике: универсальный дампер структур
// =====================================================================
//
//  Соберём всё вместе и напишем то, ради чего рефлексию обычно и
//  придумывают: ОДИН макрос, который красиво печатает ЛЮБУЮ структуру,
//  включая вложенные. Никаких `to_format` для каждого типа, никакого
//  ручного кода, который надо обновлять при добавлении поля.
//
//  В C такое невозможно без генератора кода. В Go/Java/C# это делают
//  рантайм-рефлексией (медленно, с аллокациями). В C3 — compile-time
//  рефлексией: макрос разворачивается в обычную цепочку `printf` для
//  каждого поля, как если бы вы написали её руками.
//
//  Ингредиенты, которые вы уже знаете:
//    * `$Typeof(value)` — тип значения;
//    * `$switch:` без выражения + условия на `::kind` / `::typeid` —
//      выбор ветки по виду типа;
//    * `$foreach $f : $Typeof(value)::members:` — обход полей;
//    * `value.$eval($f.name)` — доступ к полю по имени;
//    * РЕКУРСИЯ макроса: для поля-структуры макрос вызывает сам себя.
//      Это работает, потому что рекурсия идёт по ТИПАМ, а они конечны:
//      Unit -> Vec2 -> float, и на каждом уровне раскрывается своя
//      версия кода. (Структура, содержащая указатель на саму себя,
//      рекурсию бы не остановила — указатели мы печатаем как есть.)
//
//  Порядок условий в `$switch` важен: `String` — это typedef над
//  `char[]`, его `::kind` равен TYPEDEF, поэтому строки нужно поймать
//  по typeid РАНЬШЕ общих правил. Enum'ы печатаются через `%s` своим
//  именем, массивы и bool — тоже через `%s`.
//
//  Параметр `int depth = 0` — у макросов, как и у функций, бывают
//  значения по умолчанию.
//
//  ЗАДАЧА: допишите `dump_value`:
//    * строки печатаются в кавычках: "archer";
//    * float/double — с двумя знаками после точки;
//    * структура печатается как "{", затем каждое поле на новой строке
//      с отступом depth + 1 в формате "имя: значение" (значение — тем же
//      макросом), затем "}" с отступом depth.
//  Точный формат — в ожидаемом выводе (checks/088_struct_dumper.out).
//
import std::io;

enum Team { RED, BLUE }

struct Vec2
{
    float x, y;
}

struct Stats
{
    int hp;
    int armor;
    double crit;
}

struct Unit
{
    String name;
    Team team;
    Vec2 pos;
    Stats stats;
    bool alive;
    int[3] slots;
}

fn void indent(int depth)
{
    for (int i = 0; i < depth; i++) io::print("  ");
}

macro void dump_value(value, int depth = 0)
{
    $switch:
        $case $Typeof(value)::typeid == String::typeid:
            io::printfn("\"%s\"", value);
        $case $Typeof(value)::kind == STRUCT:
            io::printn("{");
            $foreach $f : $Typeof(value)::members:
                indent(depth + 1);
                io::printf("%s: ", $f.name);
                dump_value(value.$eval($f.name), depth + 1);
            $endforeach
            indent(depth);
            io::printn("}");
        $case types::is_float($Typeof(value)):
            io::printfn("%.2f", value);
        $default:
            io::printfn("%s", value);
    $endswitch
}

macro void dump(value)
{
    io::printf("%s ", $Typeof(value)::name);
    dump_value(value);
}

fn void main()
{
    Unit u = {
        .name = "archer",
        .team = BLUE,
        .pos = { 1.5, -2 },
        .stats = { 30, 2, 0.25 },
        .alive = true,
        .slots = { 1, 0, 7 },
    };
    dump(u);
    dump(u.pos);
    dump(42);
}
