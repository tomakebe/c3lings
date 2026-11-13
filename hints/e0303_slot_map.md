Чтобы менять элемент `List` на месте, берите указатель: `Slot* s = self.slots.get_ref(i);`
(`self.slots[i]` возвращает копию). Запись по индексу — `self.dense[i] = v;`.
`insert`: если `free_head != NO_SLOT` — слот из головы (`free_head = slots[si].next_free`),
иначе `si = (uint)slots.len(); slots.push({ .gen = 1 });`. Затем `used = true`,
`dense = (uint)dense.len()`, два `push`, вернуть `{ si, s.gen }`.
`remove`: если позиция не последняя — перенесите последнее значение и его номер слота
на место удаляемого и поправьте `slots[moved].dense`; затем `(void)dense.pop();`
`(void)dense_to_slot.pop();`, `used = false; gen++`, слот в голову свободного списка.
