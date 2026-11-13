`find_slot`: `sz i = (sz)hash & mask; while (true) { if (!used) return i; if (s.hash == hash && s.key == key) return i; i = (i + 1) & mask; }`.
`set`: сначала проверка загрузки и `grow()`, потом `uint h = key.hash();` и `find_slot`.
Пустой слот => заполнить key/hash/used и `len++`; в любом случае записать value.
`get`: пустой найденный слот означает `return NOT_FOUND~;`.
`remove`: освободите слот `hole`, затем `j = hole + 1` (по маске), пока `slots[j].used`:
`home = hash & mask`; если `((j - home) & mask) >= ((j - hole) & mask)` — перенести slots[j] в hole,
пометить j пустым, `hole = j`. Не забудьте `len--`.
