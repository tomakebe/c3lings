push: `t = tail.load(RELAXED)`, `h = head.load(ACQUIRE)`; если `t - h == (uint)QCAP` — полно, `false`.
Иначе записать `buf[t % QCAP] = c` и только ПОТОМ `tail.store(t + 1, RELEASE)`.
pop — зеркально: свой `head` с RELAXED, чужой `tail` с ACQUIRE, пусто при `h == t`,
прочитать ячейку и ПОТОМ `head.store(h + 1, RELEASE)`.
Вычитание `t - h` на uint корректно даже после переполнения счётчиков.
