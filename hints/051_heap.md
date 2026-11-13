Один узел: `mem::new(Node, { .value = value, .next = head })` — тип плюс инициализатор.
Массив из `count` элементов: `mem::new_array(int, count)` — результат уже срез `int[]`.
`@assert_leak` падает с отчётом «Memory leak detected», если что-то не освобождено:
сразу после выделения массива добавьте `defer free(squares);`.
