1. To boil a vector down to a single sum, vectors have the `.sum()` method.
2. `>` doesn't apply to vectors. Use the element-wise method `.comp_gt(...)` and pass it
   a vector — the `zero` variable is already declared.
3. Swizzle: the components are named x, y, z (or r, g, b). The reverse order of three components is `zyx`.
