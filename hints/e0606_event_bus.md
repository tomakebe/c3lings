`subscribe`: создайте `HandlerSlot{Type} slot = { h, ctx, priority, ++self.next_id };`,
найдите первый индекс, где `handlers[i].priority < priority` (иначе — конец списка),
и вставьте `self.handlers.insert_at(at, slot)`. Строгое `<` и даёт стабильность.
`send`: `foreach (&s : self.handlers) if (s.handler(s.ctx, &ev)) { self.consumed++; return true; }`.
`post`/`flush` — ровно как в E0603: write-буфер, swap, clear нового write, рассылка
read-буфера через `send`, вернуть его длину.
