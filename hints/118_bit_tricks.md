`next_pow2`: `1UL << (64 - (x - 1).clz())` для x > 1. `lowest_bit`: `x & (~x + 1)`.
Битсет: слово `i >> 6`, маска `1UL << (i & 63)`; set — `|=`, reset — `&= ~mask`, test — сдвиг вправо и `& 1`.
`next_set`: `ulong w = words[from >> 6] & (~0UL << (from & 63));` дальше — по словам до первого ненулевого,
индекс = `wi * 64 + w.ctz()` (не забудьте проверить `< self.bits`).
`@each_set`: `foreach (wi, word : bs.words) { ulong w = word; while (w) { @body(wi * 64 + w.ctz()); w &= w - 1; } }`.
Мортон: четыре строки с масками из шапки; `compact1by1` — те же маски снизу вверх со сдвигами вправо.
