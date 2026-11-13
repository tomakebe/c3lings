`const_value`: switch по `e.kind`; для VAR верните любую ошибку (`UNDEFINED_VARIABLE~`), остальные
рекурсивно через `!`: `int a = const_value(e.lhs)!;`. DIV/MOD на 0 — тоже ошибка («не константа»).
`expr`: начните с `if (try k = const_value(e)) { self.emit_push(k); return; }`.
GT/LE: компилируйте `rhs`, потом `lhs`, затем `LT` (+ `NOT` для LE). GE = LT + NOT, NE = EQ + NOT.
AND/OR — шаблоны из шапки: `sz f = self.emit_jump(JZ); ... self.patch_here(f);`.
`stmt`: IF — `JZ` на else; если else пуст, просто `patch_here`; иначе `JMP` на конец после then.
WHILE — `sz top = self.here();` до условия, в конце тела `emit_jump_to(JMP, top)`, затем патч выхода.
