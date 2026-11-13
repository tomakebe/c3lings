`has`: `i = entity_index(e)`; `i < sparse.len()`, `pos = sparse[i]`, `pos != NONE && entities[pos] == e`.
`get`: `self.data.get_ref(self.sparse[entity_index(e)])` (указатель, не копия).
`add`: сначала `get(e)` — если есть, перезаписать. Потом `while (sparse.len() <= i) sparse.push(NONE);`.
Если `sparse[i] != NONE` (там чужой устаревший компонент) — перезапишите `entities[pos]` и `data[pos]`;
иначе `sparse[i] = (uint)entities.len()` и два `push`.
`remove`: как в E0301, но переставлять оба массива и править `sparse[entity_index(moved)]`.
