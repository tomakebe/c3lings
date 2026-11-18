// =====================================================================
//  012 · The for loop
// =====================================================================
//
//  `for` works just like in C:
//
//      for (initialization; condition; step)
//      {
//          ...
//      }
//
//      for (int i = 0; i < 5; i++) io::printn(i);   // 0 1 2 3 4
//
//  A variable declared in the initialization is visible only inside the
//  loop. Any of the three parts can be left out: `for (;;)` is an
//  infinite loop (you get out with `break`).
//
//  SEVERAL VARIABLES
//  In C you write `for (int i = 0, j = 10; ...)`. In C3 that doesn't
//  work: each variable in the loop header is declared with ITS OWN type:
//
//      for (int i = 0, int j = 10; i < j; i++, j--) { ... }
//
//  In the step part you can list several expressions separated by
//  commas (`i++, j--`).
//
//  BOUNDS
//  The most common mistake with `for` is the off-by-one error: `<`
//  instead of `<=` or the other way around. `for (int i = 1; i < 10; i++)`
//  walks through the numbers 1..9, not 1..10.
//
//  (For iterating over arrays C3 has the more convenient `foreach` —
//  we'll get to it in exercise 021.)
//
//  TASK: fix the two places marked `// <-`. The program should print:
//
//      sum of squares 1..10 = 385
//      pairs: (0,6) (1,5) (2,4)
//      2 4 8 16 32 64
//
import std::io;

fn void main()
{
    int sum = 0;
    for (int i = 1; i < 10; i++)                // <- the numbers 1 through 10 should be included
    {
        sum += i * i;
    }
    assert(sum == 385);
    io::printfn("sum of squares 1..10 = %d", sum);

    io::print("pairs:");
    for (int lo = 0, hi = 6; lo < hi; lo++, hi--)   // <- every variable gets its own type
    {
        io::printf(" (%d,%d)", lo, hi);
    }
    io::printn();

    for (int p = 2; p <= 64; p *= 2)
    {
        io::print(p);
        if (p != 64) io::print(" ");
    }
    io::printn();
}
