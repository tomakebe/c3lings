Внутри `repeat` выделяйте через переданный аллокатор: `alloc::new_array(allocator, char, n)`.
`trepeat` — это просто `repeat`, которому передали временный аллокатор `tmem`.
Память, выделенная в `&tracker`, освобождается через него же: `alloc::free(&tracker, b)`.
