`record_frame`: `sz n = self.runs.len();` (в 0.8.5 `List.len()` возвращает знаковый `sz`), возьмите
указатель на последний элемент `&self.runs[n - 1]` и увеличьте `count`, если маска та же и
`count < ushort::max`; иначе `self.runs.push({ mask, 1 })`.
`Playback.next`: пока текущий Run исчерпан (`used >= count`) — переходите к следующему с `used = 0`;
вышли за конец — `return END_OF_REPLAY~;`, иначе `used++` и верните маску.
`verify`: `ushort? mask = pb.next(); if (catch mask) return f;` — после этого `mask` уже обычный ushort.
Индекс чекпоинта: `(sz)(sim.frame / CHECKPOINT) - 1`.
