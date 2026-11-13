Параметр-тип у макроса пишется как `$Type`: `macro usz bits_of($Type)`.
`string::tformat("%s: %d..%d", $Type::name, $Type::min, $Type::max)`.
В `make_filled` заполните массив в обычном цикле `for (int i = 0; i < $n; i++)`, приводя `($Type)value`.
