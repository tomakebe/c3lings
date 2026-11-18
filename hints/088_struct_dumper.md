The order of `$case`s matters: first `$Typeof(value)::typeid == String::typeid`, then `::kind == STRUCT`,
then `types::is_float($Typeof(value))`, and `$default` for everything else.
For a struct: `io::printn("{")`, then `$foreach $f : $Typeof(value)::members:` — `indent(depth + 1)`,
`io::printf("%s: ", $f.name)`, `dump_value(value.$eval($f.name), depth + 1)`; at the end `indent(depth)` and `"}"`.
