1. `copy_ints` writes to `dst` and reads from `src`. Writing to an `[in]` and reading from an `[out]` are forbidden —
   swap the directions.
2. The compiler sees that the argument to `isqrt` is a negative constant. The distance by the Pythagorean
   theorem: the square root of `DX*DX + DY*DY`.
3. After that, `@ensure` will catch the bug in `isqrt` at runtime: the loop takes one step too
   many. Only increase `r` while `(r + 1) * (r + 1) <= n`.
