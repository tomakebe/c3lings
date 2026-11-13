Ошибка в C3 возвращается так: `return STACK_OVERFLOW~;`. Стек полон, когда `self.sp >= STACK_MAX`, пуст — когда `self.sp <= 0`.
Бюджет проверяется ДО выполнения инструкции: `if (self.steps >= budget) return BUDGET_EXCEEDED~;`,
следом — `if (self.pc < 0 || self.pc >= code.len) return BAD_JUMP~;`.
Бинарные опкоды пишутся как ADD: `int b = self.pop()!; int a = self.pop()!; self.push(a - b)!;`.
LT кладёт `a < b ? 1 : 0`, JZ: `if (self.pop()! == 0) self.pc = ins.arg;`.
