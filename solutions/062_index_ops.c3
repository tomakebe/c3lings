// =====================================================================
//  062 · Перегрузка [], &[], []= и len — свой контейнер с foreach
// =====================================================================
//
//  `List{int}` из 054 индексируется как массив и работает с foreach.
//  Никакой магии: List просто реализует четыре «контейнерных» оператора.
//  Вы можете сделать то же самое для своего типа:
//
//      fn int    SmallVec.get(&self, sz i)        @operator([])   // v[i]
//      fn int*   SmallVec.get_ref(&self, sz i)    @operator(&[])  // &v[i]
//      fn void   SmallVec.set(&self, sz i, int x) @operator([]=)  // v[i] = x
//      fn sz     SmallVec.len(&self)              @operator(len)  // длина
//
//  Что включает каждый:
//    * `[]`   — чтение `v[i]`. Тип индекса может быть любым (у HashMap
//               это ключ-строка). Такой оператор может быть только один.
//    * `[]=`  — присваивание `v[i] = x` (и `v[i] += x`).
//    * `&[]`  — взятие адреса элемента `&v[i]`; без него `&v[i]`
//               просто не компилируется.
//    * `len`  — длина; вместе с `[]` даёт `v[^1]` («первый с конца»).
//
//  И главное — foreach:
//    * `[]` + `len`           -> `foreach (x : v)`, `foreach_r`
//    * `&[]` + `len`          -> `foreach (&x : v)` — изменение по ссылке
//
//  Внутри методов используется обычный массив, поэтому проверка границ
//  в safe-режиме работает «бесплатно». Но обратите внимание: data — это
//  int[8], а реальных элементов `count`. Оператор `len` должен
//  возвращать именно count — иначе foreach пройдёт и по «пустым» слотам.
//
//  ЗАДАЧА: подключите методы SmallVec к нужным операторам.
//  Ожидаемый вывод:
//      len 4, last 7
//      5 1 4 7
//      50 10 40 70
//      reversed: 70 40 10 50
//
import std::io;

struct SmallVec
{
    int[8] data;
    sz count;
}

fn void SmallVec.push(&self, int x)
{
    self.data[self.count++] = x;
}

fn int SmallVec.get(&self, sz i) @operator([]) => self.data[i];
fn int* SmallVec.get_ref(&self, sz i) @operator(&[]) => &self.data[i];
fn void SmallVec.set(&self, sz i, int x) @operator([]=) => self.data[i] = x;
fn sz SmallVec.len(&self) @operator(len) => self.count;

fn void main()
{
    SmallVec v;
    v.push(3);
    v.push(1);
    v.push(4);
    v.push(7);
    v[0] = 5;
    io::printfn("len %d, last %d", v.len(), v[^1]);

    foreach (x : v) io::printf("%d ", x);
    io::printn();

    foreach (&x : v) *x *= 10;
    foreach (x : v) io::printf("%d ", x);
    io::printn();

    io::print("reversed:");
    foreach_r (x : v) io::printf(" %d", x);
    io::printn();
}
