1. The address of a temporary value (a literal) is taken with the `&&` operator, not `&`.
2. A fixed-size array inside a struct is copied in full: `copy` has its own array.
3. A pointer is copied as an address: `copy.bonus` and `red.bonus` point at the same variable.
4. `reset_scores` receives a copy of the struct. To change the original, take a `Team*`
   and pass `&blue`.
