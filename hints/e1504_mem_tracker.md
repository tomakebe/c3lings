`acquire`: `void* raw = self.backing.acquire(size + HEADER, init_type, 0)!;`, заголовок —
`AllocHeader* h = raw;`, заполните size/id (`++self.next_id`)/tag (`current_tag()`), `link`,
`total_allocs++`, `tags[..].count++`, `account(tag, size)`, верните `raw + HEADER`.

`release`: `AllocHeader* h = ptr - HEADER;` → `unlink`, `count--`, `account(tag, -h.size)`,
`backing.release((void*)h, false)`.

`resize`: сначала `unlink(h)`, потом `backing.resize((void*)h, new_size + HEADER, 0)`
(блок может переехать!), затем `h = raw`, новый size, `link(h)`, `account(tag, new - old)`.
Если resize вернул ошибку — верните старый h в список и пробросьте ошибку.

`link`/`unlink` — обычный двусвязный список с головой `self.head`. В C3 `if` с `else`
требует фигурных скобок.
