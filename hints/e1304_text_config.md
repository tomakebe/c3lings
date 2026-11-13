* `@assign` устроен как `@emit`, только вместо `out.appendf(...)` — `if (key == $prefix +++ $f.name) { ...; return true; }`. Внутри макроса `return` возвращает из макроса.
* Значение: `ptr.$eval($f.name) = val.to_int()!;` — `!` пробросит MALFORMED_INTEGER наверх. Для bool удобен `switch (val) { case "true": ... case "false": ... default: return BAD_VALUE~; }`.
* Ограничение: `$if $f.has_tag("max"):` + рантайм `if (ptr.$eval($f.name) > $f.get_tag("max")) {...}`.
* Вложенная структура: `if (key.starts_with($prefix +++ $f.name +++ ".")) return @assign($prefix +++ $f.name +++ ".", &ptr.$eval($f.name), key, val, stats);`
* В `parse_config`: `foreach (i, raw : text.split(tmem, "\n"))`, `stats.line = (int)i + 1;`. После `sz? eq = line.index_of_char('=');` проверка `if (catch eq) return SYNTAX~;` превращает `eq` в обычный `sz`.
* `@assign(...)!` возвращает bool: true -> `applied++`, false -> `unknown++`.
