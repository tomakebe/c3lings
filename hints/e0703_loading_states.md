request — это обход графа в глубину: проверка `state != UNLOADED` одновременно защищает от повторов и от бесконечной рекурсии на общих зависимостях. `foreach (d : a.deps) self.request(d);` ДО `push(i)`.
В tick перебирайте по ссылке: `foreach (&a : self.assets) { ... }`, иначе вы будете менять копии.
Фаза 2: `bool changed = true; while (changed) { changed = false; ... }` — материал может стать LOADED в том же тике, что и его последняя зависимость.
Фаза 3: `Asset* a = &self.assets[self.queue[self.q_head++]];` пока `in_flight < max_in_flight && q_head < q_tail`.
