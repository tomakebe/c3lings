Kahn: set up `bool[MAX_PLUGINS] done`. While not everything has been added: find the smallest i
with `!done[i] && indegree[i] == 0`. Not found - `return DEPENDENCY_CYCLE~;`.
Found - `done[i] = true`, `order[count++] = i`, and for every q with `dep_of[i][q]` decrement `indegree[q]`.
`dependents_closure`: `out[root] = true`, then keep repeating a pass over all plugins while
something changes: a plugin joins the set if at least one of its dependencies is already in it.
