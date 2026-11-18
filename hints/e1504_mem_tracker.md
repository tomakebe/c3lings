`acquire`: `void* raw = self.backing.acquire(size + HEADER, init_type, 0)!;`, the header is
`AllocHeader* h = raw;`, fill in size/id (`++self.next_id`)/tag (`current_tag()`), `link`,
`total_allocs++`, `tags[..].count++`, `account(tag, size)`, return `raw + HEADER`.

`release`: `AllocHeader* h = ptr - HEADER;` -> `unlink`, `count--`, `account(tag, -h.size)`,
`backing.release((void*)h, false)`.

`resize`: first `unlink(h)`, then `backing.resize((void*)h, new_size + HEADER, 0)`
(the block may move!), then `h = raw`, the new size, `link(h)`, `account(tag, new - old)`.
If resize returned an error - put the old h back into the list and propagate the error.

`link`/`unlink` - an ordinary doubly linked list with head `self.head`. In C3 an `if` with `else`
requires braces.
