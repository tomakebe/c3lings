`alloc_lo` — копия `alloc` из E0202, только вместо `cap` граница `self.hi`.
`alloc_hi`: сначала `if (size > hi - lo) return null;` (иначе `hi - size` может уйти
в минус по беззнаковым), затем `start = align_down(base + hi - size, align) - base`,
проверка `start >= lo`, и `hi = start`.
Маркер нижнего стека валиден, если `m.side == LOW && m.value <= lo`; верхнего —
`m.side == HIGH && m.value >= hi`. Невалидный — `return false` без изменений.
