// =====================================================================
//  008 · Type conversions
// =====================================================================
//
//  In C numbers implicitly convert into almost anything, and that's a
//  source of lots of silent bugs. C3 only allows SAFE conversions
//  implicitly:
//
//  ALLOWED implicitly (widening, no information loss):
//      int  -> long          ichar -> int
//      int  -> double        float -> double
//
//  FORBIDDEN implicitly (needs an explicit cast `(type)x`):
//      long  -> int          narrowing: might not fit
//      double -> int         the fractional part is dropped
//      double -> float       precision is lost
//      int  <-> uint         signedness change: -1 would become 4294967295
//
//  An explicit cast is your promise to the compiler: "I know what I'm doing":
//      (int)9.99      == 9       (the fractional part is dropped)
//      (char)300      == 44      (the low 8 bits are taken: 300 - 256)
//      (uint)-1       == 4294967295
//
//  AMBIGUOUS WIDENING
//  Let `a` and `b` be int. What does `long total = a + b;` mean?
//  In C: first a + b in int (may overflow!), then widening.
//  In C3 this is an ERROR, because the widening can be done two ways:
//      (long)(a + b)     — add in int, then widen
//      (long)a + b       — widen, then add in long
//  If a + b doesn't fit into int, the results differ. You have to
//  explicitly choose what you meant. (A plain `long x = a;` is allowed:
//  there's only one option there.)
//
//  Literals are a special case: `char c = 200;` is allowed, because the
//  compiler can see that 200 fits into a char. But `char c = 300;` isn't.
//
//  TASK: fix the three compile errors (`// <-`). The program should
//  print:
//
//      total: 4000000000
//      count: 5
//      whole: 9
//      low byte of 300: 44
//
import std::io;

fn void main()
{
    int a = 2_000_000_000;
    int b = 2_000_000_000;
    long total = (long)a + b;
    assert(total == 4_000_000_000);
    io::printfn("total: %d", total);

    int n = 5;
    uint count = (uint)n;
    io::printfn("count: %d", count);

    double price = 9.99;
    int whole = (int)price;
    assert(whole == 9);
    io::printfn("whole: %d", whole);

    int big = 300;
    char low = (char)big;              // here the cast is already written
    io::printfn("low byte of 300: %d", low);
}
