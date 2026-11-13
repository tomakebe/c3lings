Страница: `self.pages[id / PAGE_SIZE]`, ячейка: `[id % PAGE_SIZE]`.
`sparse_ref`: если страницы нет — `alloc::new_array(self.alloc, uint, PAGE_SIZE)`, заполнить
`EMPTY`, сохранить, `pages_allocated++`; вернуть `&self.pages[pi][id % PAGE_SIZE]`.
`add`: `*self.sparse_ref(id) = (uint)self.dense.len(); self.dense.push(id);`.
`remove`: последний id из dense переносится на позицию удаляемого, его ячейка sparse
получает эту позицию, ячейка удаляемого — `EMPTY`, затем `(void)self.dense.pop();`.
Удаление последнего элемента тоже должно работать (порядок присваиваний важен!).
