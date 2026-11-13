Центральная функция — `slot_of`: все остальные методы начинают с `Slot* s = self.slot_of(h)!;`.
Проверка: `h.generation == 0 || h.index >= MAX_SLOTS` -> STALE, затем `!s.loaded || s.generation != h.generation` -> STALE.
В acquire поиск по id: `if (try index = self.by_id.get(id)) { ... }` — ресурс с refcount == 0 всё ещё в by_id, его надо просто «воскресить».
Снятие со стека: `uint index = self.free_list[--self.free_count];`.
collect: `for (uint i = 0; i < MAX_SLOTS; i++) if (loaded && refcount == 0) self.do_unload(i);`.
