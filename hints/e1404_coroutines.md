WAIT: `self.state = WAITING; self.wake_tick = now + (ins.arg < 1 ? 1 : ins.arg); return;` — именно `return`,
иначе скрипт продолжит выполняться в этом же тике. END: `self.state = DONE; return;`.
В tick: `if (s.state == WAITING && self.now >= s.wake_tick) s.state = READY;`,
а ошибку ловите через `if (catch err = s.resume(self.now)) { ... }`.
