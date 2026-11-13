validate: `foreach (ins : self.code) switch (ins.op) { case LOAD: case STORE: ... case JMP: ... default: break; }`.
reload: начните с `next.validate()!;` — если упадёт, старая программа останется на месте.
Соберите `int[MAX_GLOBALS] fresh;`: для каждого `name` из `next.globals` —
`if (try old = self.prog.find(name)) fresh[i] = self.values[old]; else fresh[i] = next.inits[i];`.
removed = число старых переменных минус kept. Только в самом конце: `self.values = fresh; self.prog = next;`.
