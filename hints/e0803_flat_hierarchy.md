`update_world` — та же формула, что в шапке, внутри одного цикла `for`; рекурсия не нужна.
`sort_by_depth`: два вложенных цикла «для d от 0 до max_depth, для i от 0 до count» дают
устойчивый порядок (O(n·depth) — для упражнения достаточно; в движке это counting sort).
Пишите `order[n++] = i`, затем `remap[order[k]] = k`.
При переносе: `self.parent[k] = old.parent[o] == NO_PARENT ? NO_PARENT : remap[old.parent[o]]`,
где `o = order[k]`. Частая ошибка — переставить узлы, но оставить в parent старые индексы.
