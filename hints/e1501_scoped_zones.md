`begin`: if `self.count == MAX_EVENTS` - increment `dropped` and push `-1` onto the stack
(`self.stack[self.depth++] = -1`). Otherwise write an event with `.begin = self.clock()` and
`.depth = self.depth` at index `self.count++` and push that index onto the stack.

`end`: `int idx = self.stack[--self.depth];` and, if `idx >= 0`, write `end`.

Macro: `g_prof.begin(name);` then `defer g_prof.end();` and only then `@body();` -
that way end() fires on any exit from the body, including `return`.
