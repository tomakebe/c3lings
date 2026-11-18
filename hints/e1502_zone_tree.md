`find_or_add_child`: walk `first_child` -> `next_sibling`, remembering the last node
`last`. Not found - create node `self.count++` with `first_child = next_sibling = NONE` and
hook it up either as the parent's `first_child` (if it had no children) or as `last.next_sibling`.

`add_event`: `parent = self.path[e.depth]`, then `calls++`, `total += e.end - e.begin`,
`self.path[e.depth + 1] = node`.

`compute_self`: for each node i >= 1, sum the `total` of its direct children and subtract it.

`History`: write to `samples[head]`, `head = (head + 1) % HISTORY`, `count` grows up to
HISTORY. In `stats` order doesn't matter - just walk the first `count` elements.
Careful when dividing a `ulong` by an `int`: you need an explicit cast `(ulong)self.count`.
