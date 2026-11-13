В worker пройдите `for (int n = r.lo; n < r.hi; n++)` и увеличивайте `r.count`, если `is_prime(n)`.
`create` принимает указатель на функцию потока и аргумент `void*`: `&worker` и адрес «своей» структуры `&ranges[i]`.
Дождаться потоков: `foreach (t : threads) t.join()!!;` — до чтения `ranges[i].count`.
