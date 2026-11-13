`at`: `while (cursor < events.len && events[cursor].tick <= tick)` — запомнить
`buttons` и сдвинуть курсор; затем вернуть `current` (кнопки держатся до следующей записи).
`hash_long`: 8 итераций `h ^= u & 0xFF; h *= FNV_PRIME; u >>= 8;`.
`run`: внешний цикл добавляет в `acc` длительность очередного кадра
(`frames[frame_count % frames.len]`), внутренний `while (acc >= DT_US && tick < TARGET_TICKS)`
делает тик и вычитает `DT_US`. Ввод берётся по номеру тика, а не кадра.
