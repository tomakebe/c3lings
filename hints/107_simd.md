Шаблон для всех четырёх функций: `sz i = 0; for (; i + W <= len; i += W) { ...вектор... }`,
затем `for (; i < len; i++) { ...скаляр... }` — хвост.
Загрузка: `float[<FW>] va = a[i:FW];`. Запись: `float[FW] res = <вектор>; xs[i:FW] = res[..];`.
`dot_simd`: `float[<FW>] acc = 0.0f; acc += va * vb;` и в конце `acc.sum()`.
`saturating_add`: `(ushort[<BW>])v + (ushort)add`, потом `math::min(wide, limit)` и `(char[<BW>])`.
`count_byte`: `v.comp_eq(needle).mask_to_int().popcount()` — НЕ `v == needle` (это сравнение целиком).
`relu_scale`: `math::select(v.comp_gt(zero), v * k, zero)`.
