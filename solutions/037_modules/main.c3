// =====================================================================
//  037 · Modules and imports
// =====================================================================
//
//  This is the first exercise made of SEVERAL files: the whole folder
//  exercises/037_modules/ is compiled together. Open all three files:
//  main.c3, geometry.c3, shapes.c3.
//
//  In C, "modularity" rests on #include and header files. C3 has no
//  headers at all. Every file starts with a module declaration:
//
//      module geometry;
//
//  * A module can consist of several files - they all have the same
//    `module geometry;` line, and everything declared in them is visible
//    to each other without any prefixes.
//  * Module names use lowercase Latin letters, digits and `_`.
//  * Modules can be nested: `module geometry::shapes;`.
//  * If `module` isn't written (as in all the previous single-file
//    exercises), the module name is taken from the file name.
//
//  To use someone else's module, you import it:
//
//      import geometry;           // also imports geometry::shapes!
//      import std::io, std::math; // several at once, separated by commas
//
//  Imports are recursive: submodules are pulled in automatically. And
//  the `std::core` module (home of assert, String, built-in errors...)
//  is always imported. Besides that, modules sharing a common "root"
//  see each other without an import: `geometry::shapes` implicitly sees
//  `geometry`.
//
//  The prefix rule is the most important thing here:
//
//  * TYPES (struct, enum, alias...) are written WITHOUT a prefix: `Point p;`.
//    A prefix is only needed if two modules provide the same type name.
//  * FUNCTIONS, MACROS, CONSTANTS and GLOBAL VARIABLES from another
//    module are written with a prefix - the last part of the path is
//    enough: `io::printn`, `shapes::area` (the full form
//    `geometry::shapes::area` works too). This is true even for the
//    "parent" module: from geometry::shapes, the constant PI is written
//    as `geometry::PI`.
//  * METHODS are called with a dot and need no prefix: `p.len_sq()`.
//
//  Thanks to prefixes, the code shows at a glance where a function comes
//  from, and name clashes (as in C, where all functions live in one big
//  pile) are almost nonexistent.
//
//  TASK: fix the three places marked with `// <-` (two in main.c3 and
//  one in shapes.c3).
//
module app;
import std::io;
import geometry; // <- import the geometry module

fn void main()
{
    Point a = { 3, 4 };
    Point b = { 1, 2 };
    float d = geometry::dot(a, b); // <- a function from another module
    io::printfn("dot = %.1f", d);
    io::printfn("len_sq = %.1f", a.len_sq());

    Circle c = { .center = { 0, 0 }, .radius = 2 };
    io::printfn("area = %.2f", shapes::area(c));
    io::printfn("contains (1,1): %s", shapes::contains(c, { 1, 1 }));
    io::printfn("contains (2,2): %s", shapes::contains(c, { 2, 2 }));
    assert(d == 11);
}
