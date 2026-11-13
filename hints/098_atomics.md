atomic_max: `int cur = m.load(RELAXED);` и цикл `while (value > cur && !m.compare_exchange(&cur, value, RELAXED, RELAXED)) {}`.
Если CAS провалился, cur уже содержит свежее значение — просто проверьте условие снова.
lock: `bool expected = false;` затем `while (!self.locked.compare_exchange(&expected, true, ACQUIRE, RELAXED)) { expected = false; thread::yield(); }`.
unlock: `self.locked.store(false, RELEASE);`.
