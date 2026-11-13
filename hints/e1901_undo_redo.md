`apply_command`: для SPAWN запишите в `s.e[c.target]` либо `(Entity){ .alive = true }`, либо `(Entity){}` при undo.
Для остальных — `*field_of(s, c) = undo ? c.old_value : c.new_value;`.
`execute`: ДО применения запомните `c.old_value = *field_of(s, &c)` (кроме SPAWN), примените,
затем `self.len = self.cursor` (ветка redo умирает), добавьте команду, `cursor = len`.
`undo`: `apply_command(s, &self.cmds[--self.cursor], true)`; `redo` — `cmds[self.cursor++]` с undo = false.
