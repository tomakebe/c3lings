Главное правило: пока `depth > 0`, НЕ меняйте длину `live`. Подписка — в `pending`,
отписка — `removed = true`. Указатель на элемент списка: `&self.live[i]`.
`emit`: `depth++`, цикл по индексу `for (sz i = 0; i < self.live.len(); i++)`,
копия `Listener l = self.live[i];`, пропуск `removed`, вызов `l.cb(l.ctx, self, value)`;
затем `depth--` и, если стало 0, — `finalize()`.
`finalize`: удалить помеченные `remove_at(i)` (не забудьте `i--`), дописать `pending`
в `live`, очистить `pending`. `unsubscribe_owner` удобно выразить через `unsubscribe`.
