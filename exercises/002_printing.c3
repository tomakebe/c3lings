// =====================================================================
//  002 · Comments and printing
// =====================================================================
//
//  COMMENTS
//  --------
//  C3 has three kinds of comments:
//
//      // to the end of the line
//      /* block comment */
//      <* documentation comment (doc contract) *>
//
//  An important difference from C: block comments NEST.
//
//      /* outer /* inner */ still a comment */
//
//  In C the very first `*/` would close the comment, and the rest would
//  turn into garbage. In C3 you can safely "comment out" a chunk of code
//  that already contains /* ... */.
//
//  `<* ... *>` is not just a comment: it's documentation with contracts
//  (`@param`, `@require`, ...). We'll come back to them in exercise 042.
//
//  PRINTING
//  --------
//  The `std::io` module gives you several functions:
//
//      io::print(x)          — print x without a newline
//      io::printn(x)         — print x followed by a newline
//      io::printn()          — just print a newline
//      io::printf(fmt, ...)  — formatted print without a newline
//      io::printfn(fmt, ...) — formatted print + newline
//
//  `print`/`printn` can print values of any simple type:
//  `io::printn(42)`, `io::printn(true)`, `io::printn("text")`.
//
//  The format string looks like printf from C:
//
//      %d   integer                  42
//      %s   "as is" — works for almost anything (strings, numbers,
//           bool, arrays)
//      %x   integer in hexadecimal (%X — uppercase letters)
//      %b   integer in binary (C doesn't have this!)
//      %o   in octal
//      %c   character
//      %f   floating-point number; %.2f — two digits after the point
//      %5d  field width 5 (right-aligned), %-5d — left-aligned,
//           %05d — pad with zeros
//      %%   the percent sign itself
//
//  Unlike C, where a mistake in printf is undefined behavior, the C3
//  compiler CHECKS the format string if it's known at compile time:
//  if there are fewer or more specifiers than arguments, you'll get
//  a "Too many/Too few arguments" error.
//
//  TASK: replace each `???` in the format strings with the correct
//  specifier so that the program prints exactly:
//
//      Hello, comments!
//      Answer: 42
//      Name: C3
//      Hex: ff
//      Binary: 101
//      Pi: 3.14
//      [   7]
//      Progress: 100%
//
import std::io;

fn void main()
{
    /* This code is commented out entirely.
       /* In C this nested pair would break the comment, but not in C3. */
       io::printn("You should not see this");
    */

    io::print("Hello, ");          // no newline
    io::printn("comments!");      // with a newline

    io::printfn("Answer: ???", 42);
    io::printfn("Name: ???", "C3");
    io::printfn("Hex: ???", 255);
    io::printfn("Binary: ???", 5);
    io::printfn("Pi: ???", 3.14159);
    io::printfn("[???]", 7);       // field width 4, right-aligned
    io::printfn("Progress: 100???");
}
