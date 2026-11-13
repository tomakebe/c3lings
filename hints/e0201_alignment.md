`align_up`: `(x + a - 1) & ~(a - 1)`; `is_aligned`: младшие биты `x & (a - 1)` равны нулю.
`compute_layout`: идите по полям, `off = align_up(off, f.align)`, запишите смещение,
`off += f.size`; заодно копите максимум выравнивания и сумму размеров полей.
В конце `size = align_up(off, max_align)`, `wasted = size - сумма_размеров`.
`optimal_size`: сортировка вставками — сдвигайте вправо элементы со строго меньшим
`align` (строгое сравнение даёт стабильность), затем `compute_layout(sorted[:n])`.
