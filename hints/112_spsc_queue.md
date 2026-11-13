Сначала раскладка: `Atomic{uint} head @align(CACHE_LINE);` — атрибут пишется после имени поля
(и у `tail`, и у `items` — чтобы данные не делили линию со счётчиком).
`try_push`: `uint t = self.tail.load(RELAXED); uint h = self.head.load(ACQUIRE);`
полна, если `t - h == (uint)CAP`; запись `items[t & mask]`, затем `self.tail.store(t + 1, RELEASE)`.
`try_pop`: `h` своё (RELAXED), `t` чужое (ACQUIRE); пусто при `h == t`;
сначала прочитать `items[h & mask]` в `*out`, и только потом `self.head.store(h + 1, RELEASE)`.
