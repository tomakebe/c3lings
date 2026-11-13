radix_sort: держите два среза `src = items` и `dst = scratch[:items.len]`. На проходе
`pass` байт ключа — `(key >> (pass * 8)) & 0xFF`. Посчитайте гистограмму `uint[256]`,
превратите её в префиксные суммы (exclusive: offset[b] = сумма предыдущих), разложите
элементы ПО ПОРЯДКУ в `dst[offset[b]++]` и поменяйте `src`/`dst` местами.

execute: перед `api_bind_shader` сравните `c.shader` с `self.cur_shader`, и так же для
материала и меша. При смене шейдера присвойте `cur_material = -1` и `cur_mesh = -1`.
