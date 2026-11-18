1. `fn` must be followed by the return type: `fn int square(...)`.
2. The compiler requires a `return` on every path. Add `return b;` at the end of `max`.
3. Don't forget about integer division (exercise 005): convert to `double`
   before dividing, for example `((double)a + b) / 2`.
