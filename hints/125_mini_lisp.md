Начните с Env: два вложенных цикла `for (Env* e = self; e; e = e.parent) for (Binding* b = e.first; b; b = b.next)`;
`define` — сначала поищите имя в ЭТОМ кадре, иначе `self.first = mem::tnew(Binding, { name, value, self.first });`.
eval — `while (true)`: самовычислимые `return x;`, `SYM` — `env.lookup(x.sym)`, для `PAIR` выйдите из switch (`break`).
Особые формы удобно разбирать `switch (head.sym) { case "quote": ... }` — switch по строкам работает.
TCO: в хвостовых позициях НЕ `return eval(...)`, а `x = ...; continue;` (для let/lambda ещё и `env = frame;`).
Вызов: вычислить `head`, собрать список вычисленных аргументов (`Value** tail = &list;`), BUILTIN — `f.builtin(args)`,
LAMBDA — проверить арность, `new_env(f.env)` (окружение ЗАМЫКАНИЯ!), привязать параметры, тело как begin.
