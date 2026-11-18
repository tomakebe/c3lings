// =====================================================================
//  023 · Strings from the standard library
// =====================================================================
//
//  `String` has lots of methods (see lib/std/core/string.c3). You call
//  them with a dot: `s.trim()`. The most useful ones:
//
//      s.trim()               strip whitespace from both ends
//      s.starts_with("ab")    bool
//      s.ends_with(".c3")     bool
//      s.contains("needle")   bool
//      s.index_of("x")        position of a substring (Optional, see below)
//      s.tsplit(",")          split on a separator -> String[]
//      s.to_int()             parse a number (Optional, see below)
//      s.to_double()
//      s.to_upper_tcopy()     an upper-case copy
//
//  `trim`, slices and the like do NOT copy the string: the result is a
//  view of the same bytes. Methods with a `t` (`tsplit`, `tconcat`,
//  `to_upper_tcopy`) allocate memory with the TEMPORARY allocator — it
//  is freed automatically, no need to call free. Allocators are covered
//  in detail in exercises 051–053; for now just use the t-versions.
//
//  OPTIONAL — A SNEAK PEEK
//  Parsing a number can fail ("abc" is not a number). That's why
//  `to_int()` returns not an `int` but an `int?` — "an int or an
//  error". You can't assign an `int?` to a plain `int`: the compiler
//  forces you to decide what happens on error. The simplest way is the
//  `??` operator, "a default value on error":
//
//      int n = "42".to_int() ?? 0;     // 42
//      int m = "abc".to_int() ?? -1;   // -1
//
//  Optionals are covered in detail in exercises 031–036.
//
//  TASK: parse a game save string. Fix the three places marked
//  `// <-`. The program should print:
//
//      fields: 4
//      name: Ann
//      stats total: 147
//      bad number -> -1
//      is save: true
//      upper: ANN
//
import std::io;

fn void main()
{
    String save = "   hp=100; mp=40; gold=7; name=Ann  \n";

    String clean = save.trim();
    String[] fields = clean.tsplit("; ");
    io::printfn("fields: %d", fields.len);

    String name = "?";
    int total = 0;
    foreach (field : fields)
    {
        String[] kv = field.tsplit("=");
        String key = kv[0];
        String value = kv[1];
        if (key == "name")
        {
            name = value;
            continue;
        }
        int n = value.to_int() ?? 0;
        total += n;
    }
    io::printfn("name: %s", name);
    io::printfn("stats total: %d", total);

    io::printfn("bad number -> %d", "12abc".to_int() ?? -1);
    io::printfn("is save: %s", clean.starts_with("hp=") && clean.contains("name="));
    io::printfn("upper: %s", name.to_upper_tcopy());
}
