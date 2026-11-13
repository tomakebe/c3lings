`post` — просто `self.bufs[self.write].push(ev)`.
`swap`: запомните `read = self.write`, переключите `self.write ^= 1`, очистите
НОВЫЙ write-буфер (`clear()`) и верните `&self.bufs[read]`.
`run_frame`: сначала swap, потом `foreach (ev : *read) handle(w, bus, ev);`.
Обработчики пишут через `bus.post` в другой буфер, так что итерация по read-буферу
безопасна — он не растёт под вами.
