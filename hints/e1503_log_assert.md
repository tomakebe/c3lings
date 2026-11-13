`enabled`: сравните ordinal'ы: `lvl.ordinal <= self.threshold[cat.ordinal].ordinal`.

`@log`: всё тело — внутри `if (g_log.enabled(cat, lvl)) { ... }`. Внутри:
`char[128] buf;` и `String msg = (String)io::bprintf(&buf, fmt, ...$vaarg) ?? "...";`
(`bprintf` возвращает `char[]?`), затем `g_log.formatted++` и `g_log.dispatch(...)`.

`@check`: `static bool reported;` в начале макроса, `if (#expr) return true;`, дальше
счётчик, однократный `@log(CORE, ERROR, "check failed: %s (%s) in %s",
$stringify(#expr), msg, $$FUNC)` и `return false;`. `#expr` — ровно один раз!
