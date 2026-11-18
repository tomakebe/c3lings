// =====================================================================
//  003 · Variables
// =====================================================================
//
//  A variable is declared just like in C: first the type, then the name.
//
//      int apples = 3;     // declaration with initialization
//      int pears;          // no initializer
//      pears = 5;          // assignment
//
//  ZERO INITIALIZATION BY DEFAULT
//  In C a local variable without an initializer contains garbage, and
//  reading it is undefined behavior. In C3 ALL variables (both global
//  and local) without an initializer are filled with zeros.
//  `int pears;` is exactly 0. If you really need uninitialized memory
//  (for speed), you have to say so explicitly: `int x @noinit;`.
//
//  SEVERAL VARIABLES ON ONE LINE
//  `int a, b;` is allowed, but ONLY without initializers. C's
//  `int a, b = 4;` is forbidden: it's far too easy to think that `a` is
//  also 4. Declare such variables separately.
//
//  SHADOWING IS FORBIDDEN
//  In a nested block you can't declare a variable with the same name as
//  one outside: the compiler will say "would shadow a previous declaration".
//  If you want to change the outer variable, just assign to it.
//
//  NAMES
//  Variables and functions are written in lowercase (`snake_case`),
//  types are capitalized (`Player`), constants are in ALL CAPS. The
//  compiler requires this; it's not just a recommendation.
//
//  `var` — TYPE INFERENCE
//  The `var` keyword infers the type from the initializer, but in a
//  regular function it's forbidden: C3 prefers the type to be visible
//  explicitly. `var` is meant for macros and compile-time variables
//  (`var $i`), and in regular code it requires explicit permission:
//  `var x @safeinfer = 10;`. For now, just write the type.
//
//  The `assert(condition)` function checks the condition at runtime
//  and aborts the program if it's false. We'll use it a lot so that
//  programs can check themselves.
//
//  TASK: fix the three compile errors (marked with `// <-`).
//  The program should print:
//
//      apples=3 pears=4 score=17
//
import std::io;

fn void main()
{
    int apples;
    int pears = 4;

    int score;
    assert(score == 0);             // the variable is zeroed automatically

    apples = 3;
    score = apples + pears;

    {
        int bonus = 10;
        score = score + bonus;
    }

    assert(score == 17);
    io::printfn("apples=%d pears=%d score=%d", apples, pears, score);
}
