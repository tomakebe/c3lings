Каркас: `while (true) { self.steps++; char raw = self.read_u8()!; if (raw >= Op::len) return BAD_OPCODE~;
switch (Op::from_ordinal(raw)) @jump { case HALT: ... case PUSH: self.push(self.read_i32()!)!; ... } }`.
Бинарные операции: сначала `b = pop`, потом `a = pop` (порядок!). DIV/MOD — проверка `b == 0`.
`JZ`: прочитать адрес ДО снятия условия; переход — через `self.jump(addr)!`.
`LOAD`/`STORE`: слот = `self.base + read_u8()`; он должен быть `< self.sp`.
`CALL`: проверить `fp < FRAMES_MAX` (иначе STACK_OVERFLOW), сохранить `{ self.pc, self.base }` (pc уже после операндов),
`base = sp - nargs`, прыгнуть. `RET`: `v = pop`, `sp = base`, восстановить кадр, `push(v)`.
`HALT`: вернуть `stack[sp - 1]` или 0.
