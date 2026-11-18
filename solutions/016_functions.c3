// =====================================================================
//  016 · Functions
// =====================================================================
//
//  A function is declared with the word `fn`, followed by the return
//  type, the name and the parameters:
//
//      fn int add(int a, int b)
//      {
//          return a + b;
//      }
//
//  * The return type is required. If the function returns nothing,
//    write `void`. Leaving out `fn` or the type (like `int add(...)` in
//    C, or `fn add(...)`) is an error.
//  * A function with no parameters: `fn void reset()`. The C-style
//    `(void)` isn't needed.
//  * Parameters are passed BY VALUE (they are copied). Changing a
//    parameter inside the function doesn't affect the caller.
//  * If a function returns a value, EVERY execution path must end with
//    a `return`. In C a forgotten return is undefined behavior (and
//    often just a warning); in C3 it's a compile error:
//    "Missing return statement".
//
//  THE SHORT `=>` FORM
//  If the function body is a single expression, you can write:
//
//      fn int square(int x) => x * x;
//
//  This is the same as `{ return x * x; }`.
//
//  Functions are called the usual way: `add(2, 3)`. Functions from
//  other modules take the module prefix, like `io::printn(...)`;
//  functions from your own module don't need a prefix.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      square(7) = 49
//      max(3, 9) = 9
//      max(9, 3) = 9
//      average(2, 5) = 3.50
//      Hello, Alice!
//
import std::io;

fn int square(int x) => x * x;

fn int max(int a, int b)
{
    if (a > b) return a;
    return b;
}

fn double average(int a, int b) => ((double)a + b) / 2;

fn void greet(String name)
{
    io::printfn("Hello, %s!", name);
}

fn void main()
{
    io::printfn("square(7) = %d", square(7));
    io::printfn("max(3, 9) = %d", max(3, 9));
    io::printfn("max(9, 3) = %d", max(9, 3));
    io::printfn("average(2, 5) = %.2f", average(2, 5));
    greet("Alice");
}
