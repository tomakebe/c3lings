// =====================================================================
//  047 · `constset` — a set of named constants
// =====================================================================
//
//  Remember 026: an `enum` in C3 always has the values 0, 1, 2, ...
//  with no gaps. In exchange, an enum has names (`.nameof`), `values`,
//  `from_ordinal`, and switch checks that every variant is handled.
//  Giving an enum an arbitrary number, like in C (`OK = 200`), is NOT
//  possible.
//
//  But what if the values are dictated from outside — HTTP codes, key
//  codes from a C library, bit flags? That's what `constset` is for:
//
//      constset HttpStatus : int     // the base type
//      {
//          OK = 200,
//          CREATED,                  // no value => previous + 1 = 201
//          NOT_FOUND = 404,
//      }
//
//  Properties of a constset:
//  * It's a distinct type (like typedef, see 040): `HttpStatus s = 404;`
//    is an error, you need `(HttpStatus)404`. The other way is explicit
//    too: `(int)s`.
//  * It does NOT check that the value is one of the declared ones: a
//    variable may end up holding `(HttpStatus)500`, which isn't in the
//    list. That's why a switch over a constset usually needs a `default`.
//  * Accessing a constant: `HttpStatus.OK`, and where the type is clear
//    from context (assignment, case, argument) — just `OK`.
//  * Printing with `%s` / `%d` outputs the NUMBER (a constset has no
//    names at runtime — unlike an enum).
//  * Bitwise operations work with flags: `Perm.READ | Perm.WRITE`,
//    and `if (p & Perm.WRITE)` tests a bit.
//  * The base type can be anything, even `String`. With `inline`
//    (`constset Color : inline String { ... }`) a constant implicitly
//    converts to the base type.
//
//  Rule of thumb: need a closed list of variants — `enum`; need
//  specific numbers compatible with the outside world — `constset`.
//
//  TASK: fix the four spots marked with `// <-`.
//
import std::io;

constset HttpStatus : int // <- an enum can't have values like 200
{
    OK = 200,
    CREATED,
    NO_CONTENT = 204,
    NOT_FOUND = 404,
    TEAPOT = 418,
}

constset Perm : uint
{
    EXEC = 1,
    WRITE = 2,
    READ = 4,
}

fn String describe(HttpStatus s)
{
    switch (s)
    {
        case OK:
        case CREATED:
        case NO_CONTENT: return "success";
        case NOT_FOUND: return "not found";
        case TEAPOT: return "i am a teapot";
        default: return "unknown";
    }
}

fn void main()
{
    assert((int)HttpStatus.CREATED == 201); // <- what is the value of CREATED?

    int[4] from_server = { 204, 418, 500, 404 };
    foreach (code : from_server)
    {
        HttpStatus s = (HttpStatus)code; // <- int -> HttpStatus only explicitly
        io::printfn("%d: %s", s, describe(s));
    }

    Perm mine = Perm.READ | Perm.WRITE;
    uint mode = (uint)mine; // <- Perm -> uint only explicitly
    io::printfn("mode = %d", mode);
    if (mine & Perm.WRITE) io::printn("can write");
    if (!(mine & Perm.EXEC)) io::printn("cannot execute");
    assert(mode == 6);
}
