`begin`: если `self.count == MAX_EVENTS` — увеличьте `dropped` и положите в стек `-1`
(`self.stack[self.depth++] = -1`). Иначе запишите событие с `.begin = self.clock()` и
`.depth = self.depth` по индексу `self.count++` и положите этот индекс в стек.

`end`: `int idx = self.stack[--self.depth];` и, если `idx >= 0`, запишите `end`.

Макрос: `g_prof.begin(name);` затем `defer g_prof.end();` и только потом `@body();` —
так end() сработает при любом выходе из тела, включая `return`.
