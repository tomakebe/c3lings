// =====================================================================
//  088 · Reflection in practice: a universal struct dumper
// =====================================================================
//
//  Let's put it all together and write the thing reflection is usually
//  invented for: ONE macro that nicely prints ANY struct, including
//  nested ones. No `to_format` for every type, no hand-written code that
//  has to be updated every time you add a field.
//
//  In C this is impossible without a code generator. Go/Java/C# do it
//  with runtime reflection (slow, with allocations). C3 does it with
//  compile-time reflection: the macro expands into a plain chain of
//  `printf` calls for each field, as if you had written it by hand.
//
//  Ingredients you already know:
//    * `$Typeof(value)` — the type of a value;
//    * `$switch:` with no expression + conditions on `::kind` / `::typeid` —
//      picking a branch by the kind of type;
//    * `$foreach $f : $Typeof(value)::members:` — walking the fields;
//    * `value.$eval($f.name)` — accessing a field by name;
//    * macro RECURSION: for a struct field the macro calls itself.
//      This works because the recursion goes over TYPES, and they are
//      finite: Unit -> Vec2 -> float, and each level expands its own
//      version of the code. (A struct holding a pointer to itself would
//      not stop the recursion — that's why we print pointers as is.)
//
//  The order of conditions in `$switch` matters: `String` is a typedef
//  over `char[]`, its `::kind` is TYPEDEF, so strings have to be caught
//  by typeid BEFORE the general rules. Enums print their name via `%s`;
//  arrays and bools also go through `%s`.
//
//  The `int depth = 0` parameter — macros, like functions, can have
//  default values.
//
//  TASK: finish `dump_value`:
//    * strings are printed in quotes: "archer";
//    * float/double — with two digits after the decimal point;
//    * a struct is printed as "{", then each field on its own line,
//      indented by depth + 1, in the form "name: value" (the value is
//      printed by the same macro), then "}" indented by depth.
//  The exact format is in the expected output (checks/088_struct_dumper.out).
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
        // TODO: strings, structs (recursively), float/double
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
