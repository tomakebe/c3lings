// =====================================================================
//  011 · while, do-while and the do block
// =====================================================================
//
//  WHILE checks the condition BEFORE every iteration (so the body may
//  never run at all):
//
//      while (n > 0)
//      {
//          n--;
//      }
//
//  DO-WHILE checks the condition AFTER the iteration, so the body
//  runs at least once. Just like in C, you need a semicolon after
//  `while (...)`:
//
//      do
//      {
//          tries++;
//      } while (tries < 3);
//
//  `break` leaves the loop, `continue` jumps to the next check of the
//  condition.
//
//  A DO BLOCK WITHOUT WHILE is a C3 specialty. It is a block that runs
//  exactly once, but you can jump out of it with `break`:
//
//      do
//      {
//          if (x < 0) { error = "negative"; break; }
//          if (x > 100) { error = "too big"; break; }
//          error = "none";
//      };              // <- the semicolon is REQUIRED
//
//  This replaces the C trick `do { ... } while (0)` and many of the
//  cases where C code would reach for `goto`: a chain of checks where
//  you bail out after the first failure. Without the `;` the compiler
//  assumes you forgot the `while` ("Expected 'while'").
//
//  TASK: fix the places marked `// <-`. The program should print:
//
//      collatz(6) takes 8 steps
//      menu shown 1 time(s)
//      age -5: negative
//      age 200: too old
//      age 30: valid
//
import std::io;

// The Collatz conjecture: if n is even, divide it by 2, otherwise n = 3n + 1.
// Count the steps until we reach 1.
fn int collatz_steps(int n)
{
    int steps = 0;
    while (n != 1)
    {
        if (n % 2 == 0)
        {
            n = n / 2;
        }
        else
        {
            n = 3 * n + 1;
        }
        steps++;
    }
    return steps;
}

fn String check_age(int age)
{
    String status;
    do
    {
        if (age < 0)
        {
            status = "negative";
            break;
        }
        if (age > 150)
        {
            status = "too old";
            break;
        }
        status = "valid";
    };
    return status;
}

fn void main()
{
    io::printfn("collatz(6) takes %d steps", collatz_steps(6));

    int shown = 0;
    bool want_more = false;
    do
    {
        shown++;                        // the body runs at least once
    } while (want_more);
    io::printfn("menu shown %d time(s)", shown);

    io::printfn("age -5: %s", check_age(-5));
    io::printfn("age 200: %s", check_age(200));
    io::printfn("age 30: %s", check_age(30));
}
