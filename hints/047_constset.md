1. Enum values are always 0, 1, 2... — you can't set `OK = 200` (hence the "Expected '}'" error).
   For arbitrary values, declare `constset HttpStatus : int { ... }`.
2. A constant without a value gets the previous one + 1.
3. `constset` is a distinct type: an `int` only becomes an `HttpStatus` through an explicit cast `(HttpStatus)code`.
4. The other way is explicit too: `(uint)mine`.
