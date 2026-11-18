1. A lambda with inferred types: `fn (a, b) => expression`. The compiler knows the `IntOp` type from the struct field.
2. There is no operation for the `/` symbol in the table, so `find_op` returns `null`. Check `op == null`,
   print `"%c: unknown operation"` and move on to the next symbol (`continue`).
3. Lambdas don't capture local variables. Make the threshold a global constant
   (for example, `const int THRESHOLD = 10;` at the top level) and use it.
