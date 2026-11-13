Упаковка: `(gen << INDEX_BITS) | index`, распаковка: `h & INDEX_MASK` и `h >> INDEX_BITS`.
В `destroy` достаточно `e.gen++;` — новое поколение не совпадёт ни с одним выданным хендлом.
`resolve`: если `index >= self.used` — `return STALE_HANDLE~;`; затем проверьте `e.alive` и `e.gen == handle_gen(h)`.
