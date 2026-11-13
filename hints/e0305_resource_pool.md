Внутри generic-методов берите указатель на слот: `PoolSlot{Type}* s = &self.slots[i];`.
Handle — typedef, поэтому распаковка через каст: `(uint)h & INDEX_MASK`, `(uint)h >> INDEX_BITS`,
а упаковка — `(HandleT)((s.gen << INDEX_BITS) | i)`.
`release` НЕ трогает свободный список — только `pending[pending_len++] = { i, frame }`.
`collect`: `while (k < pending_len)`; если ещё рано — `k++`, иначе `destroy_fn(&s.value)`,
слот в голову свободного списка и `pending[k] = pending[--pending_len]` (без `k++`!).
