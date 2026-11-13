Порядок `$case` важен: сначала `$Typeof(value)::typeid == String::typeid`, потом `::kind == STRUCT`,
потом `types::is_float($Typeof(value))`, и `$default` для остального.
Для структуры: `io::printn("{")`, затем `$foreach $f : $Typeof(value)::members:` — `indent(depth + 1)`,
`io::printf("%s: ", $f.name)`, `dump_value(value.$eval($f.name), depth + 1)`; в конце `indent(depth)` и `"}"`.
