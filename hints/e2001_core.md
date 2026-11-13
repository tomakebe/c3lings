`Arena.alloc`: `usz start = (self.used + align - 1) & ~(align - 1);` если `start + size > cap` — `failed++`, null.
Иначе `used = start + size`, обновить `peak`, вернуть `self.base + start`. `reset` — просто `used = 0`.
`HandlePool.alloc`: если `free_count > 0` — индекс из `free_list[--free_count]`, иначе `next_unused++`
(при `next_unused == MAX_ENTITIES` — `POOL_FULL~`). Отметить alive, `live++`, вернуть `{ index, gens[index] }`.
`valid`: индекс в границах, alive и совпадает поколение. `free`: только валидный — alive = false, `gens++`,
индекс в free_list, `live--`.
