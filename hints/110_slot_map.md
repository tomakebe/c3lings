`insert`: `uint d = (uint)self.values.len();` — будущая позиция значения. Если free list не пуст:
`SlotEntry* e = self.slots.get_ref(s); self.free_head = e.idx; e.idx = d; e.occupied = true;`
иначе `self.slots.push({ .gen = 1, .idx = d, .occupied = true })`. Потом `values.push`, `owners.push(s)`.
`is_valid`: `h.index < slots.len()` + `occupied` + совпадение `gen`.
`get`: `self.values.get_ref(self.slots[h.index].idx)`.
`remove`: если `d != last` — перенесите values/owners из `last` в `d` и сделайте
`self.slots.get_ref(owners[d]).idx = d`; затем `pop()` обоих списков (`(void)` отбрасывает Optional),
`gen++`, `occupied = false`, `e.idx = free_head; free_head = h.index`.
