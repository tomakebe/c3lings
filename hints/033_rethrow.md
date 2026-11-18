1. In `area`, the result of `int_setting(...)` is an `int?`, while the variable `w` is an `int`.
   Add the postfix `!` so that on error the function immediately returns it to the caller.
2. `perimeter` uses `!`, so it must itself be able to return an error: its result type is `int?`.
3. In `main` (a regular function without an Optional) there's nowhere to rethrow the error.
   The data is valid, so get the value out "by force": `expression!!`.
