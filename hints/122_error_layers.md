`balance`: `String? text = self.store.get(account); if (catch err = text) { switch (err) { case KEY_MISSING: return self.fail(ACCOUNT_NOT_FOUND, "no account '%s'", account)~; ... default: return err~; } }`
затем `int? value = text.to_int(); if (catch value) return self.fail(CORRUPTED, ...)~; return value;`
`transfer`: проверки -> `int a = self.balance(from)!;` ... -> `self.write_balance(from, a - amount)!;`
и сразу `defer catch { ... }` — внутри временно отключите сбои (`writes_until_failure = -1`),
`(void)self.store.put(from, string::format(mem, "%d", a));` и верните счётчик сбоев. Потом вторая запись с `!`.
`http_status`: `if (!f) return 200;` и `switch (f)` с несколькими `case` подряд для 400.
