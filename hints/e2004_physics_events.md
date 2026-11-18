`push`: into `buf[write][count[write]++]`, on overflow - `dropped++`. `swap`: `write = 1 - write; count[write] = 0;`.
`Grid.insert`: `c0 = clampi((x - r) / CELL, 0, GRID_COLS - 1)`, likewise c1 for `x + r`, r0/r1 for y;
a double loop over rows and columns, cell index `row * GRID_COLS + col`.
`detect_collisions`: for each cell, all pairs i < j; skip if the masks don't intersect the layers;
`tests++`; distance in long: `dx*dx + dy*dy < (ra+rb)^2`; push `{min, max}` if `!already_reported(q, lo, hi)`.
