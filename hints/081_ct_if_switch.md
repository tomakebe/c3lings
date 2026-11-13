Обычный `if` проверяет обе ветки для любого типа, поэтому `x.len` для int не компилируется.
Используйте `$switch:` без выражения, где каждый `$case` — условие:
`$case $Typeof(x)::typeid == String::typeid:`, `$case $Typeof(x)::kind == BOOL:`, `$case types::is_float($Typeof(x)):`, `$default:`.
В `describe` добавьте `$case String:` с выводом `string "%s" of length %d`.
