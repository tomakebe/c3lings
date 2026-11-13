`begin_frame`: `self.current ^= 1;` возьмите `FrameArena* a = &self.arenas[self.current];`,
залейте байты `a.buf[0 .. a.offset-1]` значением `POISON`, затем `a.offset = 0; self.frame++`.
Заливать нужно именно арену, которая сейчас становится текущей: она хранила кадр N-2.
`alloc` — арена из E0202, где граница `limit = min(budget, buf.len)`, а неудача
увеличивает `over_budget`.
