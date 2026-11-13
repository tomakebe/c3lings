Физический индекс любого элемента — `счётчик & self.mask()`; счётчики только растут.
`len`: `(sz)(self.tail - self.head)` — беззнаковое вычитание корректно и после переполнения.
`push`: проверка `is_full()` -> `return FULL~;`, запись в `items[tail & mask]`, `tail++`.
`push_overwrite`: если полон — сначала `head++` (выбросить самый старый).
`pop`: зеркально, по `head`.
`get`/`get_ref`: логический индекс i -> `(self.head + (uint)i) & self.mask()`.
