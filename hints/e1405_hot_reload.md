validate: `foreach (ins : self.code) switch (ins.op) { case LOAD: case STORE: ... case JMP: ... default: break; }`.
reload: start with `next.validate()!;` - if it fails, the old program stays in place.
Build `int[MAX_GLOBALS] fresh;`: for each `name` in `next.globals` -
`if (try old = self.prog.find(name)) fresh[i] = self.values[old]; else fresh[i] = next.inits[i];`.
removed = number of old variables minus kept. Only at the very end: `self.values = fresh; self.prog = next;`.
