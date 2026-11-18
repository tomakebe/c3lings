In C3 an error is returned like this: `return STACK_OVERFLOW~;`. The stack is full when `self.sp >= STACK_MAX` and empty when `self.sp <= 0`.
The budget is checked BEFORE executing an instruction: `if (self.steps >= budget) return BUDGET_EXCEEDED~;`,
followed by `if (self.pc < 0 || self.pc >= code.len) return BAD_JUMP~;`.
Binary opcodes are written like ADD: `int b = self.pop()!; int a = self.pop()!; self.push(a - b)!;`.
LT pushes `a < b ? 1 : 0`, JZ: `if (self.pop()! == 0) self.pc = ins.arg;`.
