Ресэмплинг: `usz i = (usz)(pos >> 16)`, `int frac = (int)(pos & 0xFFFF)`; соседи a = input[i], b = input[i+1]
(за концом — `input[^1]`); результат `a + (((b - a) * frac) >> 16)`; после записи `pos += step`.
Фильтр: держите y в локальной переменной, в конце сохраните в `self.y`.
ADSR: `switch (self.stage)`: ATTACK прибавляет `1/attack` и при >= 1 переходит в DECAY;
DECAY вычитает `(1 - sustain)/decay` и при <= sustain переходит в SUSTAIN; RELEASE вычитает `release_step`
и при <= 0 обнуляет уровень и переходит в IDLE. В C3 у `case` нет проваливания — `break` не нужен.
