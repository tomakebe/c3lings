`foreach (i, name : $Enum::names)` and on a match `return $Enum::from_ordinal(i);`; after the loop — `return NOT_FOUND~;`.
Methods: `$foreach $m : Robot::methods:` — `$m` is a string with the method's name.
Filtering by prefix: `$if $m.len > 4 &&& $m[0..3] == "cmd_":`, calling: `r.$eval($m)();`.
