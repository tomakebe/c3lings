`foreach (i, name : $Enum::names)` и при совпадении `return $Enum::from_ordinal(i);`, после цикла — `return NOT_FOUND~;`.
Методы: `$foreach $m : Robot::methods:` — `$m` это строка с именем метода.
Отбор по префиксу: `$if $m.len > 4 &&& $m[0..3] == "cmd_":`, вызов `r.$eval($m)();`.
