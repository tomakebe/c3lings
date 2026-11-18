// =====================================================================
//  022 · Strings: String, ZString, raw strings
// =====================================================================
//
//  STRING
//  C3's main string type is `String`. Under the hood it's a byte slice
//  `char[]`: a pointer + a length. That means:
//  * the length is known right away: `s.len` (no strlen, O(1));
//  * a string does NOT have to be zero-terminated (a slice from the
//    middle of another string is a String too);
//  * indexing `s[0]`, slicing `s[1..3]`, `foreach (c : s)` — all work
//    just like with slices.
//  The contents are UTF-8 bytes; `len` is the number of BYTES, not
//  characters.
//
//  ZSTRING
//  `ZString` is a C-style zero-terminated string (essentially a
//  `char*`). You need it to call C functions. Its length has to be
//  computed: `z.len()` walks up to the zero (like strlen).
//  A string literal "..." works for both types. But the two don't
//  convert into each other implicitly:
//      ZString -> String:  `z.str_view()`  (a view of the same bytes)
//      String -> ZString:  needs a copy with a trailing zero (`s.zstr_tcopy()`)
//
//  COMPARISON
//  In C, `a == b` on strings compares ADDRESSES, and you have to call
//  strcmp. In C3, `==` on String compares the CONTENTS: `"abc" == s`
//  does exactly what you'd expect.
//
//  ESCAPE SEQUENCES AND RAW STRINGS
//  In a regular string, `\` starts an escape sequence (`\n`, `\t`,
//  `\\`, `\"`...). An unknown sequence (like `\g`) is a compile error:
//  "Invalid escape in string".
//  A raw string is written in backticks `...` and is taken LITERALLY:
//  backslashes stay as they are, and a newline inside is simply part
//  of the string. Handy for Windows paths, regular expressions and
//  multi-line text.
//
//      String path = `C:\games\new`;      // exactly what you see
//
//  Adjacent literals are concatenated: "abc" "def" == "abcdef".
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      path: C:\games\new (12 bytes)
//      title: Hello (5 bytes)
//      command is quit
//      'l' count: 3
//
import std::io;

fn void main()
{
    String path = "C:\games\new";                 // <- the backslashes must stay as they are
    io::printfn("path: %s (%d bytes)", path, path.len);

    ZString c_title = "Hello";                    // pretend this came from a C library
    String title = c_title;                       // <- a ZString doesn't implicitly become a String
    io::printfn("title: %s (%d bytes)", title, title.len);

    String input = "quit now";
    String command = input[0:4];                  // a slice of a string is a String too
    if (command == "quit") io::printn("command is quit");

    int count = 0;
    foreach (c : "hello world")
    {
        if (c == ???) count++;                    // <- a character literal for the letter l
    }
    io::printfn("'l' count: %d", count);
}
