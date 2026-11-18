`enabled`: compare ordinals: `lvl.ordinal <= self.threshold[cat.ordinal].ordinal`.

`@log`: the whole body goes inside `if (g_log.enabled(cat, lvl)) { ... }`. Inside:
`char[128] buf;` and `String msg = (String)io::bprintf(&buf, fmt, ...$vaarg) ?? "...";`
(`bprintf` returns `char[]?`), then `g_log.formatted++` and `g_log.dispatch(...)`.

`@check`: `static bool reported;` at the start of the macro, `if (#expr) return true;`, then
the counter, a one-time `@log(CORE, ERROR, "check failed: %s (%s) in %s",
$stringify(#expr), msg, $$FUNC)` and `return false;`. `#expr` exactly once!
