`pf.next_chunk.add(1)` атомарно увеличивает счётчик и возвращает СТАРОЕ значение — это и есть номер вашего куска.
Выход из цикла — когда `chunk * pf.chunk_size >= pf.count`. Конец куска не должен выходить за `count` (последний кусок короче).
В `parallel_sum`: `float[] partial = mem::new_array(float, (sz)chunks); defer free(partial);`, затем `SumCtx ctx = { data, partial };` и `parallel_for(threads, data.len, chunk_size, &sum_body, &ctx)`.
Сложите `partial` обычным `foreach` по порядку — именно фиксированный порядок делает сумму одинаковой при любом числе потоков.
