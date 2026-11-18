// =====================================================================
//  005 · Floating-point numbers
// =====================================================================
//
//  Two types, just like in C:
//
//      float    32 bits, ~7 significant decimal digits
//      double   64 bits, ~16 significant digits
//
//  Literals:
//      3.14        double (the default type)
//      3.14f       float (suffix f)
//      1.5e3       1500.0 — scientific notation
//      1_000.5     underscores are allowed here too
//
//  INTEGER DIVISION
//  If both operands are integers, division is integer division:
//  `7 / 2 == 3`. In C the expression `double avg = sum / count;` (sum and
//  count being int) would quietly give 3.0 instead of 3.5 — a classic
//  bug. C3 is stricter here: it won't implicitly widen the result of an
//  integer expression to double ("the widening of the expression may be
//  done in more than one way"), because it's unclear what you meant —
//  `(double)(sum / count)` (3.0) or `(double)sum / count` (3.5).
//  You need to write an explicit cast: `(type)expression`.
//
//  NARROWING
//  `double -> float` loses precision, so it's not allowed implicitly:
//  `float f = some_double;` is an error, you need `(float)some_double`.
//  But `int -> double` or `float -> double` is safe and implicit.
//
//  COMPARISON
//  Numbers like 0.1 can't be represented exactly in binary, so
//  `0.1 + 0.2 == 0.3` is FALSE. Compare with a tolerance:
//  `math::abs(a - b) < 1e-9` (requires `import std::math;`).
//
//  PRINTING
//  `io::printn(x)` prints 6 digits after the point: `3.500000`.
//  With the `%.2f` format you can set the number of digits: `3.50`.
//
//  TASK: fix the places marked with `// <-`. The program should
//  print:
//
//      average: 3.50
//      speed: 2.25
//      big: 1500.0
//      0.1 + 0.2 == 0.3? false
//      close enough? true
//
import std::io;
import std::math;

fn void main()
{
    int sum = 7;
    int count = 2;
    double average = (double)sum / count;
    assert(average == 3.5);
    io::printfn("average: %.2f", average);

    double distance = 4.5;
    float speed = (float)(distance / 2);
    io::printfn("speed: %.2f", speed);

    double big = 1.5e3;
    io::printfn("big: %.1f", big);

    double x = 0.1 + 0.2;
    io::printfn("0.1 + 0.2 == 0.3? %s", x == 0.3);
    io::printfn("close enough? %s", math::abs(x - 0.3) < 1e-9);
}
