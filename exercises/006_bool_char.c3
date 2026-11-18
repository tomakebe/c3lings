// =====================================================================
//  006 · bool and char
// =====================================================================
//
//  BOOL
//  The `bool` type has two values: `true` and `false`. Logical operators
//  are the same as in C: `&&`, `||`, `!`. Comparisons (`==`, `<`, ...)
//  produce a bool.
//
//  In C `bool` is essentially a number, and `bool b = 1;` works. In C3
//  `int` and `bool` do NOT implicitly convert into each other:
//
//      bool b = 1;         // error
//      bool b = true;      // correct
//      int  i = true;      // error; but (int)true == 1 is fine
//
//  (That said, an integer is allowed in a condition like `if (x)` — it
//  is compared against zero.)
//
//  CHAR
//  `char` is an unsigned 8-bit type (a byte). A character literal in
//  single quotes is just a number, the ASCII code of the character:
//  'A' == 65, 'a' == 97, '0' == 48. So you can do arithmetic with
//  characters:
//
//      'a' + 1          == 'b'
//      '7' - '0'        == 7      (digit character -> number)
//      'a' - 'A'        == 32     (distance between the cases)
//
//  Printing: `%c` prints the character, `%d` prints its code. Be
//  careful: `io::printn(c)` for a char prints a NUMBER, not a letter.
//
//  ESCAPE SEQUENCES (in characters and strings)
//      \n  newline            \t  tab            \0  null byte
//      \\  backslash          \'  apostrophe     \"  double quote
//      \x41  a byte with a hexadecimal code (here 'A')
//  There are no octal escape sequences (like `\101` in C), except
//  for `\0`.
//
//  TASK: fix the places marked with `// <-`. The program should
//  print:
//
//      ready: true
//      upper: C (code 67)
//      digit: 7
//      quote: '
//      path: C:\games
//
import std::io;

fn void main()
{
    bool ready = 1;                         // <- bool is not a number
    io::printfn("ready: %s", ready);

    char letter = 'c';
    char upper = letter - ???;              // <- how far apart are 'a' and 'A'?
    assert(upper == 'C');
    io::printfn("upper: %c (code %d)", upper, upper);

    char digit_char = '7';
    int digit = digit_char - '0';
    assert(digit == 7);
    io::printfn("digit: %d", digit);

    char quote = ''';                       // <- a single quote must be escaped
    io::printfn("quote: %c", quote);

    io::printn("path: C:\\games");
}
