WAIT: `self.state = WAITING; self.wake_tick = now + (ins.arg < 1 ? 1 : ins.arg); return;` - it must be `return`,
otherwise the script keeps running in the same tick. END: `self.state = DONE; return;`.
In tick: `if (s.state == WAITING && self.now >= s.wake_tick) s.state = READY;`,
and catch the error with `if (catch err = s.resume(self.now)) { ... }`.
