`alive`: `i < self.generations.len() && self.generations[i] == entity_gen(e)`.
`create`: если `self.free_count() > MIN_FREE` — `i = self.free_queue[self.free_head++]` и
`self.compact_queue()`; иначе `i = (uint)self.generations.len(); self.generations.push(0);`.
Затем `live++` и `make_entity(i, self.generations[i])`.
`destroy`: `generations[i] = (ushort)((generations[i] + 1) & GEN_MASK)`, `free_queue.push(i)`, `live--`.
