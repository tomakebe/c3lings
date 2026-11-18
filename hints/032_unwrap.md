1. In `parse_score`, after `if (catch err = v) { ... }` the compiler still treats `v` as `int?`,
   because the block can "fall through" further down. Return the caught error: `return err~;`.
2. Which error does `"abc".to_int()` return? String errors live in the `string` module
   (see `excuse` in `.c3c/c3/lib/std/core/string.c3`); from another module they're written with a prefix: `string::...`.
3. The "run only if there is a result" form is `if (try name = expression)`.
