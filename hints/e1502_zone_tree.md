`find_or_add_child`: пройдите по `first_child` → `next_sibling`, запоминая последний узел
`last`. Не нашли — создайте узел `self.count++` с `first_child = next_sibling = NONE` и
прицепите его либо в `first_child` родителя (если детей не было), либо в `last.next_sibling`.

`add_event`: `parent = self.path[e.depth]`, затем `calls++`, `total += e.end - e.begin`,
`self.path[e.depth + 1] = node`.

`compute_self`: для каждого узла i ≥ 1 сложите `total` прямых детей и вычтите.

`History`: пишем в `samples[head]`, `head = (head + 1) % HISTORY`, `count` растёт до
HISTORY. В `stats` порядок не важен — просто пройдите первые `count` элементов.
Осторожно с делением `ulong` на `int`: нужен явный каст `(ulong)self.count`.
