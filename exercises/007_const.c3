// =====================================================================
//  007 · Constants
// =====================================================================
//
//  A constant is declared with the `const` keyword:
//
//      const int MAX_HP = 100;
//      const GREETING = "hello";     // the type can be omitted
//
//  Rules:
//  * A constant's name is in UPPERCASE letters. This isn't style, it's
//    a compiler requirement: `const int max_hp` is an error
//    "Names of consts must be all uppercase".
//  * The value must be known at compile time. Constants can be computed
//    from other constants: `const int AREA = WIDTH * HEIGHT;`
//    — the compiler calculates it itself, and the program just contains
//    a number.
//  * You can't assign a new value to a constant.
//
//  In C you'd usually write `#define MAX_HP 100` for this. C3 has no
//  preprocessor, and `const` takes its place — and on top of that, a
//  constant has a type and obeys scopes and module rules.
//
//  The word `const` in C3 is NOT a type qualifier like in C (there is no
//  `const char*` here). It only means "compile-time constant".
//
//  Where a compile-time constant is needed:
//  * an array size: `int[SLOTS] inventory;` — a regular variable won't
//    work here ("Expected a constant value as length").
//  * `$assert(condition)` — a check at COMPILE TIME. If the condition
//    is false, the program simply won't build. It costs nothing at
//    runtime and catches bugs earlier than `assert`.
//
//  TASK: fix the two compile errors marked with `// <-`.
//  The program should print:
//
//      Welcome to the dungeon
//      hp=100 area=48 slots=4
//
import std::io;

const GREETING = "Welcome to the dungeon";
const int max_hp = 100;                 // <- what's wrong with the name?
const int WIDTH = 8;
const int HEIGHT = 6;
const int AREA = WIDTH * HEIGHT;        // computed at compile time

$assert(AREA == 48);                    // compile-time check

fn void main()
{
    io::printn(GREETING);

    int slot_count = 4;                 // <- an array size must be a constant
    int[SLOT_COUNT] inventory;

    io::printfn("hp=%d area=%d slots=%d", MAX_HP, AREA, inventory.len);
}
