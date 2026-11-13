`resolve`: заведите `remaining = pressed` и `result = 0`, идите `for (int i = self.depth - 1; i >= 0; i--)`.
Для каждого контекста копите отдельную маску `consumed` и вычитайте её из `remaining` только
ПОСЛЕ обхода всех привязок контекста. Если `ctx.blocking` — `break`.
`rebind`: сначала проверка конфликта (`b.control == new_control && b.action != a`), потом
`foreach (&b : self.bindings)` — по ссылке, чтобы изменить привязку на месте.
Ошибки возвращаются как `return CONFLICT~;`, успех — просто `return;`.
