`conflicts`: `(a.writes & (b.reads | b.writes)) != 0 || (b.writes & (a.reads | a.writes)) != 0`.
Шаг 1: для `pos` от 0 до n-1 ищите наименьший `i`, который ещё не взят и у которого ВСЕ
`after[k]` уже взяты; не нашли — `return false`. Запишите `order[pos] = i; rank[i] = pos`.
Шаг 2: обходите `i = order[pos]` по возрастанию `pos`; для каждого `j` с `rank[j] < rank[i]`,
который указан в `i.after` или конфликтует с `i`, `st = max(st, stage[j] + 1)`.
`stage_count` — максимум `stage + 1`. Этапы раньше вычислены, потому что идём в порядке `order`.
