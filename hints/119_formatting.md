Каждый `to_format` копит счётчик: `sz n = f.print("[")!; n += ...!; ... return n;`
`Vec2f`: один `f.printf("(%.2f, %.2f)", self.x, self.y)`.
`Pair`: `<`, `@print_elem(f, self.first)!`, `", "`, второй элемент, `>`.
`Stack`: `foreach (i, v : self.items[:self.len])`, перед всеми элементами кроме первого — `", "`.
Вложенность получается сама: `@print_elem` зовёт `f.printf("%s", v)`, а тот — `to_format` элемента.
