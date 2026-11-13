`alias clamp_int = numeric::clamp{int};`
Ошибка про `max` возникает потому, что `struct Tagged <Type>` с тем же именем параметра попадает
в одну группу с `module numeric <Type>`: `Tagged{String}` тянет за собой `max{String}`.
Если совсем застряли: переименуйте параметр структуры, например `struct Tagged <Value>` (и тип поля тоже).
