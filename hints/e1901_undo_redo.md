`apply_command`: for SPAWN write either `(Entity){ .alive = true }` or, on undo, `(Entity){}` into `s.e[c.target]`.
For the rest - `*field_of(s, c) = undo ? c.old_value : c.new_value;`.
`execute`: BEFORE applying, remember `c.old_value = *field_of(s, &c)` (except for SPAWN), apply it,
then `self.len = self.cursor` (the redo branch dies), append the command, `cursor = len`.
`undo`: `apply_command(s, &self.cmds[--self.cursor], true)`; `redo` - `cmds[self.cursor++]` with undo = false.
