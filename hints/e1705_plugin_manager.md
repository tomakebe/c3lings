Кан: заведите `bool[MAX_PLUGINS] done`. Пока не все добавлены: найдите наименьший i,
у которого `!done[i] && indegree[i] == 0`. Не нашли — `return DEPENDENCY_CYCLE~;`.
Нашли — `done[i] = true`, `order[count++] = i`, и для всех q с `dep_of[i][q]` уменьшите `indegree[q]`.
`dependents_closure`: `out[root] = true`, затем повторяйте проход по всем плагинам, пока
что-то меняется: плагин попадает в множество, если хоть одна его зависимость уже там.
