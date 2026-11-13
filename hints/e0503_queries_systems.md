Макрос: `if (a.len() <= b.len()) { for (sz k = 0; k < a.len(); k++) { view_visits++;
Entity e = a.entities[k]; var y = b.get(e); if (y) @body(e, a.data.get_ref(k), y); } } else { ...симметрично... }`.
Порядок аргументов в `@body` всегда (e, компонент_из_a, компонент_из_b).
`destroy_now`: `if (!self.alive(e)) return;` — это и защищает от двойного DESTROY.
`flush`: `foreach (c : self.commands.array_view()) switch (c.kind) { case DESTROY: ... case SPAWN_SPARK: ... }`,
затем `self.commands.clear()`. Искра: `create()`, `pos.add(s, { c.pos })`, `life.add(s, { 3 })`.
