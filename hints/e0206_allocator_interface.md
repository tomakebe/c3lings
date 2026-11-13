`acquire`: `align = alignment ? alignment : DEFAULT_ALIGN` (не меньше `Header::alignment`);
`user = align_up(base + offset + Header::size, align) - base` — смещение данных,
заголовок лежит по `user - Header::size`. Лимит — `min(budget, buf.len)`, проверка как в E0202.
`resize`: используйте готовый `is_last(ptr)`. На месте: `h.size = new_size; offset = user + new_size`.
Иначе: `void* p = self.acquire(new_size, NO_ZERO, alignment)!;` скопируйте
`min(h.size, new_size)` байт (`mem::copy` принимает `sz`) и вызовите `self.release(ptr, ...)`.
`release`: если `is_last(ptr)` — `offset = h.start`.
