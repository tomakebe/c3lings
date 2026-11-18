// =====================================================================
//  009 · Operators and precedence
// =====================================================================
//
//  Arithmetic is the same as in C: `+ - * / %`, increments `++ --`,
//  compound assignments `+= -= *= ...`. Bitwise: `& | ^ ~ << >>`.
//  Logical: `&& || !`. There's no exponentiation operator (`2 ** 3` is
//  "2 times the dereference of 3", an error).
//
//  PRECEDENCE DIFFERS FROM C! From highest to lowest (simplified):
//
//      1. postfix: () [] . ++ --
//      2. prefix: - ~ ! * &
//      3. * / %
//      4. << >>
//      5. & | ^           (all three are ONE level)
//      6. ?: ??
//      7. + -
//      8. == != < > <= >=  (all one level)
//      9. &&
//     10. ||
//     11. ? :  (ternary)
//     12. = += -= ...
//
//  What follows from this:
//  * `a & b == c` in C means `a & (b == c)` (a famous trap),
//    while in C3 it's `(a & b) == c`, just as you'd want.
//  * Shifts and bitwise operators bind TIGHTER than addition:
//    `1 + 2 << 3` in C3 is `1 + (2 << 3)` == 17, while in C it's 24.
//  * Mixing operators of the same "merged" level without parentheses is
//    NOT ALLOWED: `a | b & c` or `a < b == c` is an error "You need to add
//    explicit parentheses". Nobody remembers how the precedences of `|`,
//    `^` and `&` differ in C, so C3 simply requires parentheses.
//
//  The REMAINDER `%` takes the sign of the dividend: `-7 % 3 == -1`,
//  `7 % -3 == 1`.
//
//  OVERFLOW
//  In C signed integer overflow is undefined behavior. In C3 it's
//  DEFINED: values "wrap around" modulo 2^N (two's complement).
//  `int::max + 1 == int::min`. Division by zero and shifting by too
//  many bits abort the program with a clear message in a debug build.
//
//  TASK: fix the three places marked with `// <-`. The program should
//  print:
//
//      mixed: 3
//      shifted: 24
//      has flag: true
//      wrapped: -128
//      remainder: -1
//
import std::io;

fn void main()
{
    int a = 1;
    int b = 6;
    int c = 3;
    int mixed = a | (b & c);
    io::printfn("mixed: %d", mixed);

    int shifted = (1 + 2) << 3;
    assert(shifted == 24);
    io::printfn("shifted: %d", shifted);

    int flags = 0b1010;
    bool has_flag = flags & 0b0010 == 0b0010;   // in C3 this works as intended
    io::printfn("has flag: %s", has_flag);

    ichar small = 127;
    small++;                            // overflow is well-defined
    assert(small == -128);
    io::printfn("wrapped: %d", small);

    io::printfn("remainder: %d", -7 % 3);
}
