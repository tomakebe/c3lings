Successors строятся «переворотом» рёбер: если задача i зависит от d, то i — последователь d: `d.successors[d.succ_count++] = i;`.
Алгоритм Кана: заведите `int[MAX_TASKS] indegree` и `bool[MAX_TASKS] emitted`. На каждом из `count` шагов ищите первую (наименьшую по индексу) невыведенную задачу с `indegree == 0`.
Не нашли такую — в графе цикл, верните false. Нашли — запишите в `order[n]`, пометьте и уменьшите `indegree` её последователям.
`on_task_done`: `if (self.tasks[s].pending.sub(1) == 1) self.push_ready(s);` — `sub` возвращает значение ДО вычитания.
