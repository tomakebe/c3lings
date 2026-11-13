Начните с `insert`: цикл `while (self.nodes[node].first_child != NONE) node = ... + quadrant(&self.nodes[node], p);`.
В `split` координаты ребёнка: `n.x + (k & 1 ? half : 0)`, `n.y + (k & 2 ? half : 0)`.
При обходе списка сохраняйте `int nxt = self.next[id];` ДО `push_point` — он меняет `next[id]`.
После `push` в `List` не используйте старые указатели `QNode*` — берите `&self.nodes[node]` заново.
Индекс List'а вида `self.nodes[first + k]` C3 не примет без приведения — заведите `int child = first + k;`.
`query`: «не пересекается», если `q.x > max_x || q.x + q.size - 1 < min_x` (и так же по y).
