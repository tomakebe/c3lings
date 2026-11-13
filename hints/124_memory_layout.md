Fat: по убыванию выравнивания — сначала оба `double`, затем `int`, `short`, и в конце три однобайтовых поля.
Атрибуты пишутся после имени типа: `struct PaddedCounter @align(CACHE_LINE)`, `struct Header @packed`.
`align_up`: `(x + a - 1) & ~(a - 1)`.
`compute_layout`: `sz end = 0;` для каждого поля `off = align_up(end, f.align)`, `end = off + f.size`,
`l.align = max(l.align, f.align)`; в конце `l.size = align_up(end, l.align)` — хвостовой padding.
