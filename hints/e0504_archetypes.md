`remove_row`: `last = entities.len() - 1`; если `row != last` — для каждого `c` с `mask & bit(c)`
`mem::copy(self.at(c, row), self.at(c, last), (sz)COMPONENT_SIZE[c])`, затем
`moved = entities[last]; entities[row] = moved;`. В конце `(void)entities.pop()`.
`move_entity`: `rec = records[(uint)e]`, `from`, `ti = find_or_create(new_mask)`, `row = to.push_row(e)`;
скопируйте компоненты из `from.mask & new_mask`; `moved = from.remove_row(rec.row)` и, если
`moved != NO_ENTITY`, `records.get_ref((uint)moved).row = rec.row`; наконец `records[(uint)e] = { ti, row }`.
Внимание: `find_or_create` может добавить архетип в список — берите указатели ПОСЛЕ него
(сами `Archetype*` стабильны, они в куче).
