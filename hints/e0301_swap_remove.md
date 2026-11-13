`remove`: `i = index_of[id]`, `last = len - 1`. Если `i != last` — скопируйте `items[last]`
и `owner_of[last]` в позицию `i` и обновите `index_of` у ПЕРЕЕХАВШЕГО владельца.
Затем `index_of[id] = -1; len--`.
`remove_dead`: цикл `while (i < len)`; если элемент мёртв — `remove(owner_of[i])` и НЕ
увеличивать `i` (в позиции `i` теперь новый элемент), иначе `i++`.
