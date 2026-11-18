`line`: the algorithm is written out almost verbatim in the header of main.c3: `dx = |x1-x0|`, `dy = -|y1-y0|`, `sx`, `sy` = ±1,
`err = dx + dy`, an infinite loop with `put` and an exit once the end point is reached.
`circle`: x = r, y = 0, err = 1 - r; while `x >= y` - 8 points `(cx±x, cy±y)` and `(cx±y, cy±x)`; then `y++`;
if `err < 0` - `err += 2*y + 1`, otherwise `x--; err += 2*(y - x) + 1`.
Profiler: `begin` - `find_or_add`, `calls++`, `stack[depth++] = z`; `end` - `depth--`;
`add_work` - into zone `stack[depth - 1]` (if depth > 0).
