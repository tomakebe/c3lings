Работайте в адресах: `base = (usz)self.buf.ptr`, `cap = (usz)self.buf.len`,
`start = align_up(base + self.offset, align) - base` — это смещение начала блока.
Место есть, если `start <= cap && size <= cap - start` (так сумма не переполнится).
Иначе `failed++` и `return null`. При успехе: `offset = start + size`, обновить `peak`
и `allocs`, вернуть `self.buf.ptr + start`. `reset` обнуляет `offset` и `allocs` (но не `peak`).
