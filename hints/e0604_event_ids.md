Compile-time FNV-1a: `var $h = 2166136261u;` затем
`$for var $i = 0; $i < $name.len; $i++: $h = ($h ^ $name[$i]) * 16777619u; $endfor`
и `return $h;`. Runtime-версия — то же самое через `foreach (c : name)` с `uint h`
(умножение uint и так идёт по модулю 2^32).
`@check_unique`: два вложенных `$for` по `EVENT_NAMES.len` (j от i + 1), внутри
`$assert @event_id(EVENT_NAMES[$i]) != @event_id(EVENT_NAMES[$j]) : "...";` и `$pairs++;`.
`name_of`: перебрать EVENT_NAMES и сравнить `event_id(n) == id`.
