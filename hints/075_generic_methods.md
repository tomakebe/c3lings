Методы generic-типа не помечаются `<Type>` — параметр приходит от структуры. Уберите его у `push`.
`pop`: уменьшите `self.len` и верните `self.items[self.len]` (можно в одну строку: `self.items[--self.len]`).
`peek`: верхний элемент — `self.items[self.len - 1]`.
`sum`: `foreach (v : *self)` работает благодаря `@operator([])` и `@operator(len)`.
