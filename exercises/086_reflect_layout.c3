// =====================================================================
//  086 · Reflection: fields, sizes, offsets
// =====================================================================
//
//  Reflection is a program's ability to learn about its own types: which
//  fields a struct has, what their types are, where they live in memory.
//  C has only `sizeof` and `offsetof`; C++ had no field reflection at all
//  before C++26 (hence macros like BOOST_DESCRIBE); Zig has `@typeInfo`.
//  In C3 almost everything is available at compile time via `::` on a
//  type and `$reflect(...)` on a value.
//
//  Type properties (compile-time constants):
//
//      Foo::size          // size in bytes (sizeof)
//      Foo::alignment     // alignment
//      Foo::name          // "Foo";  Foo::qname — "mymodule::Foo"
//      Foo::kind          // TypeKind.STRUCT
//      Foo::typeid        // typeid — this one can be stored at runtime too
//      Foo::members       // compile-time list of fields
//
//  Each element of `Foo::members` describes a field:
//
//      $f.name     // "x"
//      $f.type     // the field's typeid: $f.type.name, $f.type.size, $f.type.kind
//      $f.offset   // offset in bytes from the start of the struct (offsetof)
//      $f.size     // size of the field
//
//  `::members` is an "untyped" compile-time list, so you iterate over it
//  with `$foreach` (or pick an element by a constant index:
//  `Foo::members[1].name`). You can't put it into a runtime variable.
//
//  For expressions there is `$reflect`:
//
//      $reflect(p.x).offset        // offset of a field
//      $reflect(Particle.y).offset // works through the type as well
//      $reflect(p).size
//
//  Why care about layout? The compiler aligns fields: a `double` must sit
//  at an address that is a multiple of 8, so after a `char` it inserts
//  7 bytes of nothing (padding). Field order affects the struct's size:
//
//      struct Bad  { char a; double b; char c; }   // 24 bytes
//      struct Good { double b; char a; char c; }   // 16 bytes
//
//  For an array of a million particles that's megabytes and cache misses.
//  The rule "sort fields by decreasing alignment" often saves memory for
//  free. (More on layout in exercise 124.)
//
//  typeid is available at runtime too: `typeid t = Foo::typeid; t.size,
//  t.kind, t.name` — but `members` exists only at compile time.
//
//  TASK:
//    1. In the `layout` macro, compute the total size of the fields
//       (`used`) and print a line for each field as in the expected output.
//    2. The fields of `Particle` are laid out poorly. Reorder them (without
//       changing types or names) so that the struct takes 16 bytes.
//
module layout_demo;
import std::io;

struct Particle
{
    char alive;
    double x;
    short id;
    float y;
}

struct Vec3
{
    float x, y, z;
}

macro void layout($Type)
{
    io::printfn("%s: size=%d align=%d", $Type::name, $Type::size, $Type::alignment);
    usz used = 0;
    $foreach $f : $Type::members:
        // TODO: print a line about field $f and add its size to used
    $endforeach
    io::printfn("  padding=%d", $Type::size - used);
}

fn void main()
{
    layout(Particle);
    layout(Vec3);

    $assert Particle::size == 16 : "Particle should fit in 16 bytes";

    Particle p;
    io::printfn("offset of p.y via $reflect: %d", $reflect(p.y).offset);
    io::printfn("second member: %s", Particle::members[1].name);
    io::printfn("kind: %s, qname: %s", Particle::kind, Particle::qname);

    typeid t = Vec3::typeid;      // a runtime value
    io::printfn("runtime typeid: size=%d kind=%s", t.size, t.kind);
}
