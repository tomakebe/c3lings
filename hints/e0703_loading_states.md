request is a depth-first graph traversal: the `state != UNLOADED` check guards both against repeats and against infinite recursion on shared dependencies. `foreach (d : a.deps) self.request(d);` BEFORE `push(i)`.
In tick, iterate by reference: `foreach (&a : self.assets) { ... }`, otherwise you will be modifying copies.
Phase 2: `bool changed = true; while (changed) { changed = false; ... }` — a material can become LOADED in the same tick as its last dependency.
Phase 3: `Asset* a = &self.assets[self.queue[self.q_head++]];` while `in_flight < max_in_flight && q_head < q_tail`.
