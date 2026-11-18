// =====================================================================
//  032 · Unwrapping Optionals: `if (catch ...)`, `if (try ...)`
// =====================================================================
//
//  In the previous exercise we only "peeked" into an Optional with
//  @ok/@catch. But to actually GET the value out, you need unwrapping.
//
//  1) `if (catch err = opt) { ... }`
//
//     If the Optional is empty, its error (of type `fault`) is stored in
//     `err` and the body runs. The name can be omitted: `if (catch opt) ...`.
//     A `switch` is a handy way to examine the error - cases on fault values:
//
//         if (catch err = value)
//         {
//             switch (err)
//             {
//                 case NOT_FOUND: ...
//                 case io::EOF:   ...    // errors from other modules need a prefix
//                 default:        ...
//             }
//         }
//
//  2) Flow typing (inferring types from control flow) is the killer
//     feature. If the body of `if (catch ...)` is guaranteed to LEAVE the
//     current scope (`return`, `break`, `continue`, ...), then after that
//     `if` the compiler KNOWS there is no error, and the variable becomes
//     a plain `int` instead of `int?`:
//
//         int? v = s.to_int();
//         if (catch err = v) return err~;  // pass the error up
//         // here v is already just an int!
//         return v * 2;
//
//     If, however, the catch block can "fall through" downward, `v` stays
//     an `int?`, and you can't work with it as a number.
//
//     Note the `return err~;` - a caught error can be returned further
//     with the same `~` suffix.
//
//  3) `if (try v = opt) { ... }` is the opposite form: the body runs
//     only if there IS a result, and inside it `v` is a plain value.
//     If the Optional is already a variable, you can skip the new name:
//     `if (try opt) { /* here opt is a plain int */ }`.
//     Multiple conditions can only be joined with `&&`:
//
//         if (try a = f() && try b = g()) { ... a + b ... }
//
//  The standard library returns Optionals too: `String.to_int()`
//  returns an `int?` with errors like `string::MALFORMED_INTEGER`.
//
//  TASK: fix the three places marked with `// <-`.
//
import std::io;

excuse EMPTY_INPUT, OUT_OF_RANGE;

fn int? parse_score(String s)
{
    if (s.len == 0) return EMPTY_INPUT~;
    int? v = s.to_int();
    if (catch err = v)
    {
        io::printfn("  cannot parse '%s'", s);
        // <- the catch block must leave the function
    }
    // Thanks to flow typing, v is a plain int here.
    if (v < 0 || v > 100) return OUT_OF_RANGE~;
    return v;
}

fn void main()
{
    String[] inputs = { "90", "", "abc", "75", "250", "-1", "35" };
    int total;
    int empty;
    int malformed;
    int out_of_range;

    foreach (s : inputs)
    {
        int? score = parse_score(s);
        if (catch err = score)
        {
            switch (err)
            {
                case EMPTY_INPUT: empty++;
                case ???: malformed++; // <- which error does "abc" produce?
                case OUT_OF_RANGE: out_of_range++;
                default: unreachable("unexpected fault");
            }
            continue;
        }
        total += score;
    }

    io::printfn("total=%d empty=%d malformed=%d out_of_range=%d",
                total, empty, malformed, out_of_range);
    assert(total == 200 && empty == 1 && malformed == 1 && out_of_range == 2);

    if (??? best = parse_score("100")) // <- run only if there is a result
    {
        io::printfn("best=%d", best);
    }
    if (try a = parse_score("40") && try b = parse_score("2"))
    {
        io::printfn("a+b=%d", a + b);
    }
}
