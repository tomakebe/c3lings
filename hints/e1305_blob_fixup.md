* `validate`: на каждое поле одна строка вида `if (!range_ok(h.vertices.offset, h.vertex_count, Vertex::size, Vertex::alignment, blob.len)) return BAD_OFFSET~;`. Для строк элемент = 1 байт, количество = `len + 1` (завершающий 0).
* Подмеши до fixup ещё не указатель: `Submesh* sm = (Submesh*)(blob.ptr + h.submeshes.offset);`. Сумму `first_index + index_count` считайте в `ulong`, чтобы не переполнилась.
* `fixup`: `self.vertices.ptr = base + self.vertices.offset;` и так для всех полей; материалы подмешей — после того, как `submeshes` стал указателем (`foreach (&sm : self.get_submeshes())`).
* `unfixup`: разность указателей — знаковое число, нужен явный каст: `(ulong)((char*)self.name.ptr - base)`. Материалы — первыми.
* `RelPtr`: `get` — `(char*)self + self.off` (0 означает null), `set` — `(int)((char*)target - (char*)self)`.
