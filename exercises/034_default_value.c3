// =====================================================================
//  034 · `??` - default values and Optional "laziness"
// =====================================================================
//
//  Often you want to respond to an error simply: "didn't work - use a
//  default value". That's what the `??` operator is for:
//
//      int port = parse_port(text) ?? 8080;
//
//  If the left side has a result, it's used; if it's an empty Optional,
//  the right side is used. The result is NO LONGER an Optional (if the
//  right side is a plain value).
//
//  The right side is evaluated LAZILY - only if the left side is an
//  error, like the second operand of `||` in C. So you can even call an
//  expensive function on the right:
//
//      Config c = load_user_config() ?? load_default_config();
//
//  The right side can also be a DIFFERENT error - this is how you
//  "rename" an error so the caller better understands what happened:
//
//      int? n = text.to_int() ?? BAD_PORT~;   // MALFORMED_INTEGER -> BAD_PORT
//
//  And `?? BAD_PORT~!` renames it and rethrows it right away (`!` from 033).
//
//  The second important property is calling a function with an Optional
//  argument. The function `fn int double_it(int x)` takes a plain `int`.
//  What happens if you pass it an `int?`?
//
//      int? r = double_it(maybe_number);
//
//  If `maybe_number` holds a value, the function is called as usual.
//  If it holds an error, the function is NOT CALLED AT ALL, and `r` gets
//  that same error. Arguments are checked left to right, and the first
//  error wins. That's exactly why `io::printfn("%d", maybe)` with an
//  empty Optional silently prints nothing, and the compiler requires
//  you to explicitly discard the result: `(void)io::printfn(...)` - so
//  you won't be surprised.
//
//  This is convenient (the error "leaks" through the call chain on its
//  own), but remember: the function's side effects won't happen on error.
//
//  TASK: fix the four places marked with `// <-`. Two of them ask you
//  to predict how many times a function was actually called.
//
import std::io;

excuse BAD_PORT;

int default_calls;
int double_calls;

fn int default_port()
{
    default_calls++;
    return 8080;
}

fn int double_it(int x)
{
    double_calls++;
    return x * 2;
}

fn int? load_port(String text)
{
    // Replace the number-parsing error with our own, clearer one.
    return text.to_int() ?? ???; // <- rename the error
}

fn void main()
{
    int p1 = load_port("3000") ??? default_port(); // <- default value
    int p2 = load_port("oops") ?? default_port();
    io::printfn("p1=%d p2=%d", p1, p2);
    assert(p1 == 3000 && p2 == 8080);
    assert(default_calls == 2); // <- how many times was default_port() called?

    int? d1 = double_it(load_port("21"));
    int? d2 = double_it(load_port("twenty"));
    assert(double_calls == 2); // <- and double_it()?

    io::printfn("d1=%d", d1 ?? -1);
    io::printfn("d2=%d", d2 ?? -1);
    assert(@catch(d2) == BAD_PORT);

    // Optionals in arithmetic: if any operand is empty, the whole thing is empty.
    int sum = (load_port("1") + load_port("x") + load_port("2")) ?? 0;
    io::printfn("sum=%d", sum);
}
