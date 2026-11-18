// =====================================================================
//  041 · Function pointers and lambdas
// =====================================================================
//
//  In 039 we declared a function pointer type with alias. Now let's
//  see what we can actually do with it.
//
//      alias IntOp = fn int(int, int);
//
//  * Store it in variables, arrays, struct fields:
//
//        IntOp[2] ops = { &add, &sub };
//        struct Button { String label; Action on_click; }
//
//    Careful: you can't write `fn void() on_click;` directly in a
//    struct field or a parameter — a function pointer type is ALWAYS
//    declared through an alias.
//  * Pass it to functions and return it from functions.
//  * Call it: `ops[0](2, 3)` — just like a regular function.
//  * The pointer can be `null` (that's the default value!). Calling a
//    null pointer crashes the program, so check first:
//    `if (op == null) ...`.
//
//  LAMBDAS are anonymous functions written right inside an expression:
//
//      IntOp mul = fn int(int a, int b) { return a * b; };  // full form
//      IntOp mul = fn int(int a, int b) => a * b;           // short form
//      IntOp mul = fn (a, b) => a * b;    // types inferred from context
//
//  The last form only works where the compiler knows which type is
//  needed: when assigning to a variable of a known type, when passing
//  to a parameter, in an array initializer.
//
//  The main limitation: C3 lambdas DO NOT CAPTURE local variables
//  (they aren't closures). A lambda is just an ordinary function
//  without a name, with no hidden "environment". It can see globals and
//  constants, but not the local variables of the enclosing function.
//  Need some context? Pass it explicitly as a parameter (for example,
//  `void* user_data`, like C libraries do) or use globals/constants.
//
//  TASK: a tiny calculator applies operations by their symbol.
//  Fix the three spots marked with `// <-`.
//
import std::io;

alias IntOp = fn int(int, int);
alias Pred = fn bool(int);

struct OpEntry
{
    char symbol;
    IntOp op;
}

fn int add(int a, int b) => a + b;

OpEntry[3] table = {
    { '+', &add },
    { '-', fn (a, b) => a - b }, // <- write a lambda for subtraction
    { '*', fn int(int a, int b) { return a * b; } },
};

fn IntOp find_op(char symbol)
{
    foreach (e : table)
    {
        if (e.symbol == symbol) return e.op;
    }
    return null;
}

fn int count_if(int[] values, Pred p)
{
    int n;
    foreach (v : values) if (p(v)) n++;
    return n;
}

const int THRESHOLD = 10; // <- a lambda can't see local variables

fn void main()
{
    String program = "+-*/";
    int[] results = { 0, 0, 0, 0 };
    foreach (i, c : program)
    {
        IntOp op = find_op(c);
        if (op == null) // <- what if there is no such operation?
        {
            io::printfn("%c: unknown operation", c);
            continue;
        }
        results[i] = op(12, 3);
        io::printfn("%c: 12 %c 3 = %d", c, c, results[i]);
    }

    Pred big = fn (x) => x > THRESHOLD;
    int n = count_if(results, big);
    io::printfn("results > %d: %d", THRESHOLD, n);
    assert(n == 2);
}
