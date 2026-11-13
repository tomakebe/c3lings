`line`: алгоритм записан в шапке main.c3 почти дословно: `dx = |x1-x0|`, `dy = -|y1-y0|`, `sx`, `sy` = ±1,
`err = dx + dy`, бесконечный цикл с `put` и выходом при достижении конца.
`circle`: x = r, y = 0, err = 1 - r; пока `x >= y` — 8 точек `(cx±x, cy±y)` и `(cx±y, cy±x)`; затем `y++`;
если `err < 0` — `err += 2*y + 1`, иначе `x--; err += 2*(y - x) + 1`.
Профайлер: `begin` — `find_or_add`, `calls++`, `stack[depth++] = z`; `end` — `depth--`;
`add_work` — в зону `stack[depth - 1]` (если depth > 0).
