`link_last`: если `p.first_child == NONE` — `p.first_child = id`, иначе `node(p.last_child).next_sibling = id`; затем `p.last_child = id`.
`detach`: пройдите от `first_child`, запоминая `prev`, пока не встретите `id`. Перешейте ссылку
(`first_child` или `prev.next_sibling`), поправьте `last_child = prev`, если id был последним.
`attach`: `for (NodeId a = new_parent; a != NONE; a = node(a).parent) if (a == id) return CYCLE~;`
`subtree_sum`: `while (try id = self.stack.pop()) { ... push всех детей ... }`.
`write_sexpr`: лист — просто имя; иначе `(`, имя, для каждого ребёнка пробел + рекурсия, `)`.
