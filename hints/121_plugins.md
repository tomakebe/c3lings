`load`: проверки по порядку — версия, затем `if (!p.init || !p.update || !p.shutdown) return MISSING_FUNCTION~;`.
Состояние: `void* state = p.state_size > 0 ? mem::calloc(p.state_size) : null;`;
при `!p.init(&self.api, state)` — `free(state)` и `INIT_FAILED~`. Потом `self.plugins.push({ p, state })`.
`broadcast`: вызывать `lp.api.on_event(...)` только если указатель не null.
`unload_all`: `foreach_r (lp : self.plugins) { shutdown; free(lp.state); }`, затем `clear()`.
`reset_all`: `if (&t.reset) { t.reset(); n++; }`.
