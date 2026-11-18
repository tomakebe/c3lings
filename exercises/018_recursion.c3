// =====================================================================
//  018 · Recursion, no overloading, and declaration order
// =====================================================================
//
//  DECLARATION ORDER DOESN'T MATTER
//  In C a function has to be declared (or at least have a prototype)
//  BEFORE its first use — hence header files and prototypes at the top
//  of the file. In C3 the compiler sees the whole module at once: you
//  can call a function above the place where it is defined. There are
//  no prototypes. In this exercise `main` comes first and calls
//  functions that are defined further down.
//
//  RECURSION
//  A function can call itself. The key thing is a base case that stops
//  the recursion:
//
//      fn int factorial(int n)
//      {
//          if (n <= 1) return 1;          // base case
//          return n * factorial(n - 1);   // recursive step
//      }
//
//  Without a base case the recursion never ends, the stack overflows,
//  and the program crashes.
//
//  NO FUNCTION OVERLOADING
//  Just like in C (and unlike C++), a module can't have two functions
//  with the same name, even if their parameters differ: "would shadow
//  a previous declaration". Every function gets its own name
//  (`power`, `ipower`). For generic code C3 has macros and generics —
//  more on those later.
//
//  TASK: fix the places marked `// <-`. The program should print:
//
//      fib: 0 1 1 2 3 5 8 13 21 34
//      gcd(48, 18) = 6
//      ipower(2, 10) = 1024
//      power(1.5, 2) = 2.25
//
import std::io;

fn void main()
{
    io::print("fib:");
    for (int i = 0; i < 10; i++) io::printf(" %d", fib(i));
    io::printn();

    io::printfn("gcd(48, 18) = %d", gcd(48, 18));
    io::printfn("ipower(2, 10) = %d", ipower(2, 10));
    io::printfn("power(1.5, 2) = %.2f", power(1.5, 2));
}

// fib(0) = 0, fib(1) = 1, fib(n) = fib(n-1) + fib(n-2)
fn int fib(int n)
{
    if (???) return n;                     // <- the base case
    return fib(n - 1) + fib(n - 2);
}

// Euclid's algorithm: gcd(a, 0) = a, otherwise gcd(b, a % b)
fn int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);

fn double power(double base, int exp)
{
    if (exp == 0) return 1.0;
    return base * power(base, exp - 1);
}

fn int power(int base, int exp)            // <- no overloading: what does main call it?
{
    if (exp == 0) return 1;
    return base * ipower(base, exp - 1);
}
