The central function is `slot_of`: every other method starts with `Slot* s = self.slot_of(h)!;`.
The check: `h.generation == 0 || h.index >= MAX_SLOTS` -> STALE, then `!s.loaded || s.generation != h.generation` -> STALE.
In acquire, look up by id: `if (try index = self.by_id.get(id)) { ... }` — a resource with refcount == 0 is still in by_id; just "resurrect" it.
Popping the stack: `uint index = self.free_list[--self.free_count];`.
collect: `for (uint i = 0; i < MAX_SLOTS; i++) if (loaded && refcount == 0) self.do_unload(i);`.
