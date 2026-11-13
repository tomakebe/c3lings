Элементы deque лежат в полуинтервале `[top, bottom)`, индексы растут бесконечно, а в массив обращаемся через `% DEQUE_CAP`.
`pop_bottom`: проверить пустоту, затем `self.bottom--` и взять `items[self.bottom % DEQUE_CAP]`. `steal_top`: взять `items[self.top % DEQUE_CAP]`, затем `self.top++`.
Оба метода — под мьютексом deque (`lock()` + `defer unlock()`).
`try_steal`: цикл `for (int k = 1; k < s.worker_count; k++)` с `victim = (id + k) % s.worker_count` — так себя никогда не посетим.
Выравнивание задаётся атрибутом после имени структуры: `struct WorkerStats @align(64) { ... }`.
