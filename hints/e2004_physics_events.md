`push`: в `buf[write][count[write]++]`, при переполнении — `dropped++`. `swap`: `write = 1 - write; count[write] = 0;`.
`Grid.insert`: `c0 = clampi((x - r) / CELL, 0, GRID_COLS - 1)`, аналогично c1 для `x + r`, r0/r1 для y;
двойной цикл по строкам и столбцам, индекс ячейки `row * GRID_COLS + col`.
`detect_collisions`: для каждой ячейки все пары i < j; пропустить, если маски не пересекаются со слоями;
`tests++`; расстояние в long: `dx*dx + dy*dy < (ra+rb)^2`; push `{min, max}`, если `!already_reported(q, lo, hi)`.
