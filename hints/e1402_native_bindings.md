`find`: `for (int i = 0; i < self.count; i++) if (self.items[i].name == name) return i;` - C3 strings are compared with `==`.
`@bind`: `$if $Typeof($f)::params.len == 0:` - a branch with `fn int?(int[] a, void* ctx) => $f()`,
otherwise the arity is `$Typeof($f)::params.len` and the trampoline is `=> $f(...a[:$Typeof($f)::params.len])`.
`link`: `int idx = natives.find(s.name)!;` and compare `natives.items[idx].arity` with `s.arg2`.
CALL: `int base = self.sp - n.arity;`, call `n.func(self.stack[base:n.arity], self.ctx)!`, then `self.sp = base;` and push the result.
