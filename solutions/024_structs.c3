// =====================================================================
//  024 · Structs
// =====================================================================
//
//  DECLARATION
//
//      struct Vec2
//      {
//          int x;
//          int y;
//      }
//
//  Unlike C:
//  * no semicolon is needed after the `}`;
//  * no `typedef struct ... Vec2;` is needed — the name `Vec2` is a
//    type right away, you don't write `struct Vec2 v;` when using it;
//  * a type name starts with a capital letter, but can NOT be all
//    capitals: `Vec2` is fine, `VEC2` or `P` is an error ("Names of
//    structs cannot be all uppercase"). All-caps names are reserved for
//    constants.
//
//  INITIALIZATION
//      Vec2 a = { 1, 2 };              // positional: in field order
//      Vec2 b = { .y = 5, .x = 3 };    // named (designated)
//      Vec2 c = { .x = 7 };            // y = 0 (anything unspecified is zero)
//      Vec2 d;                         // { 0, 0 }
//
//  The positional form depends on field order: reorder the fields in
//  the declaration and every such initializer silently changes meaning
//  (or stops compiling). For structs with several fields the named
//  form is more robust.
//
//  NESTED STRUCTS are initialized with nested braces, and in the named
//  form you can address a field of the nested struct directly:
//
//      Player p = { .name = "Ann", .pos = { 1, 2 } };
//      Player q = { .name = "Bob", .pos.x = 4 };
//
//  Fields are accessed with a dot: `p.pos.x`.
//
//  A STRUCT IS A VALUE. Assignment and passing to a function copy the
//  whole thing. There's no `==` for structs by default (compare the
//  fields, or overload the operator — exercise 063). And `%s` doesn't
//  print a struct's fields, so we print the fields by hand.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      Ann: hp=100 at (3, 4)
//      Bob: hp=80 at (0, 7)
//      copy: hp=100, original: hp=90
//
import std::io;

struct Vec2
{
    int x;
    int y;
}

struct Hero
{
    String name;
    int hp;
    Vec2 pos;
}

fn void describe(Hero h)
{
    io::printfn("%s: hp=%d at (%d, %d)", h.name, h.hp, h.pos.x, h.pos.y);
}

fn void main()
{
    Hero ann = { "Ann", 100, { 3, 4 } };
    describe(ann);

    Hero bob = { .name = "Bob", .hp = 80, .pos.y = 7 };
    describe(bob);

    Hero copy = ann;
    ann.hp -= 10;
    io::printfn("copy: hp=%d, original: hp=%d", copy.hp, ann.hp);
}
