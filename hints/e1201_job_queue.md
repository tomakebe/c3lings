Все три функции начинаются с `self.mtx.lock()` и заканчиваются `unlock()` (в `pop` удобно сразу написать `defer self.mtx.unlock();`).
Ожидание на условной переменной — всегда в цикле `while (условие_не_выполнено) self.cv.wait(&self.mtx);`.
В `push` ждём, пока `count() == QUEUE_CAP`; в `pop` — пока `count() == 0 && !self.quitting`.
Не забудьте будить вторую сторону: `push` делает `not_empty.signal()`, `pop` — `not_full.signal()`.
`shutdown` обязан использовать `broadcast()`, иначе проснётся только один рабочий, а остальные будут спать вечно (программа зависнет на join).
