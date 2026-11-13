`find`: `for (int i = 0; i < self.count; i++) if (self.items[i].name == name) return i;` — строки C3 сравниваются через `==`.
`@bind`: `$if $Typeof($f)::params.len == 0:` — ветка с `fn int?(int[] a, void* ctx) => $f()`,
иначе арность `$Typeof($f)::params.len` и трамплин `=> $f(...a[:$Typeof($f)::params.len])`.
`link`: `int idx = natives.find(s.name)!;` и сравнение `natives.items[idx].arity` с `s.arg2`.
CALL: `int base = self.sp - n.arity;`, вызов `n.func(self.stack[base:n.arity], self.ctx)!`, потом `self.sp = base;` и push результата.
