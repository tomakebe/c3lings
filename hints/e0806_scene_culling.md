Все три функции — простые циклы; вся «умность» в порядке узлов (DFS preorder).
`update_world`: `IVec base = p == NO_PARENT ? { 0, 0 } : self.world_pos[p];` — дальше сложение
и `self.local_box[i].offset(self.world_pos[i])`.
`update_bounds`: сначала скопируйте world_box в sub_box для всех; затем
`for (int i = self.count - 1; i > 0; i--)` сливайте ребёнка в родителя — к моменту обработки
узла все его потомки (они правее) уже в него влиты.
`cull`: при промахе по `sub_box` делайте `i = self.subtree_end[i]; continue;` — без `i++`.
Счётчик `tests` растёт на каждую проверку `overlaps`: одна для sub_box и одна для world_box.
