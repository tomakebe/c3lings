// =====================================================================
//  033 · Rethrowing an error with `!` and force-unwrapping with `!!`
// =====================================================================
//
//  Very often a function doesn't know what to do with an error and just
//  wants to pass it on to the caller. Writing this every time
//
//      int? tmp = foo();
//      if (catch err = tmp) return err~;
//
//  gets tedious. That's what the postfix `!` operator ("rethrow") is for:
//
//      int x = foo()!;
//
//  If `foo()` has an error, the current function immediately returns
//  that same error. If not, `x` gets a plain value (`int`, not `int?`).
//  It's the equivalent of `?` in Rust or `try` in Zig.
//
//  Important: `!` can only be used in a function that itself returns an
//  Optional (`int?`, `void?`, `String?`...). Otherwise, where would the
//  error go? The compiler checks this.
//
//  The second operator is `!!` ("force unwrap"):
//
//      int x = foo()!!;
//
//  If there's no error, you get the value. If there is one, the program
//  CRASHES with a panic. This isn't error handling, it's an assertion:
//  "there can't be an error here, and if there is, it's a bug". It fits
//  in tests, in prototypes, and where the input is known to be valid.
//  Unlike `!`, `!!` can be written in any function.
//
//  Optional chaining: `!` can be applied to any expression, including
//  directly to a method call: `line[i + 1..].to_int()!`.
//
//  `main` can't return an Optional, so errors "bubble up" to some level
//  where they get handled (if-catch) or where we're sure there are none
//  (`!!`).
//
//  TASK: fix the three places marked with `// <-`.
//
import std::io;

excuse WRONG_KEY, NO_EQUALS;

// "width=640" + "width" -> "640"
fn String? value_of(String line, String key)
{
    sz? eq = line.index_of_char('=');
    if (catch eq) return NO_EQUALS~;
    if (line[:eq] != key) return WRONG_KEY~;
    return line[eq + 1..];
}

fn int? int_setting(String line, String key)
{
    String text = value_of(line, key)!;
    return text.to_int();
}

fn int? area(String w_line, String h_line)
{
    int w = int_setting(w_line, "width")!; // <- the error needs to be rethrown
    int h = int_setting(h_line, "height")!;
    return w * h;
}

fn int? perimeter(String w_line, String h_line) // <- the function uses `!`
{
    int w = int_setting(w_line, "width")!;
    int h = int_setting(h_line, "height")!;
    return 2 * (w + h);
}

fn void report(String w_line, String h_line)
{
    int? a = area(w_line, h_line);
    if (catch err = a)
    {
        io::printfn("%s / %s -> error %s", w_line, h_line, err.description);
        return;
    }
    io::printfn("%s / %s -> area %d", w_line, h_line, a);
}

fn void main()
{
    report("width=4", "height=5");
    report("width=4", "heigth=5");
    report("width4", "height=5");
    report("width=x", "height=5");

    // This data is known to be valid - there can't be an error.
    int p = perimeter("width=10", "height=20")!!; // <- get the value out "by force"
    io::printfn("perimeter %d", p);
    assert(p == 60);
}
