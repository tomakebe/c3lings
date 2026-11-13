Порядок шага как в Box2D: скорости -> контакты -> ITERATIONS проходов солвера -> положения -> коррекция -> сон.
Обходите тела по ссылке: `foreach (&b : self.bodies) { if (!b.awake) continue; ... }`.
Солвер: `for (int it = 0; it < ITERATIONS; it++) foreach (&c : self.contacts) resolve_contact(self.body(c.a), self.body(c.b), c);`.
`advance`: цикл `while (self.accumulator >= DT && steps < MAX_SUBSTEPS)`; после него остаток `>= DT`
означает «спираль смерти» — `self.accumulator = 0`. Затем `self.alpha = self.accumulator / DT`.
Сон: таймер копится только пока тело почти неподвижно; любое движение сбрасывает его в 0.
