`Arena.alloc`: `usz start = (self.used + align - 1) & ~(align - 1);` if `start + size > cap` - `failed++`, null.
Otherwise `used = start + size`, update `peak`, return `self.base + start`. `reset` is just `used = 0`.
`HandlePool.alloc`: if `free_count > 0` - the index comes from `free_list[--free_count]`, otherwise `next_unused++`
(when `next_unused == MAX_ENTITIES` - `POOL_FULL~`). Mark it alive, `live++`, return `{ index, gens[index] }`.
`valid`: index in bounds, alive and the generation matches. `free`: only a valid handle - alive = false, `gens++`,
index into free_list, `live--`.
