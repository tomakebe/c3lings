// =====================================================================
//  054 · List{T} — динамический массив
// =====================================================================
//
//  Срез из `mem::new_array` имеет фиксированную длину. Когда заранее
//  неизвестно, сколько будет элементов, нужен растущий массив — в C3
//  это `List` из модуля `std::collections::list` (аналог std::vector
//  в C++ или Vec в Rust).
//
//      import std::collections::list;
//
//      List{int} nums;          // generic-тип: параметр в ФИГУРНЫХ скобках
//      nums.init(mem);          // какой аллокатор использовать
//      defer nums.free();       // список владеет буфером — освобождаем
//
//  Синтаксис generic'ов в C3 — `List{int}`, а не `List<int>` как в C++/Java.
//  Часто для инстанцирования заводят alias: `alias IntList = List{int};`.
//
//  Основные операции:
//      nums.push(5);              добавить в конец
//      nums.push_all({1, 2, 3});  добавить несколько
//      nums.len()                 количество элементов (usz)
//      nums[i]                    чтение по индексу (с проверкой границ)
//      nums[i] = x;               запись по индексу
//      nums.pop()                 снять последний — возвращает int?  (!)
//      nums.first(), nums.last()  тоже Optional: списка может быть пуст
//      nums.remove_at(i)          удалить со сдвигом хвоста
//      nums.insert_at(i, x)       вставить со сдвигом
//      nums.contains(x), nums.index_of(x)    (index_of тоже Optional)
//      nums.array_view()          срез на текущее содержимое
//
//  `pop()` возвращает Optional, потому что из пустого списка снимать
//  нечего — ошибка `NO_MORE_ELEMENT`. Значит, результат нужно
//  распаковать: `?? значение_по_умолчанию`, `!!`, `if (try ...)` и т.д.
//
//  `foreach` работает со списком как с массивом, включая изменение
//  по ссылке: `foreach (&x : nums) *x *= 2;`
//  И `io::printn(nums)` печатает `[1, 2, 3]`.
//
//  Про аллокатор: если `init` не вызвать, список при первом `push`
//  сам инициализируется ВРЕМЕННЫМ аллокатором (tmem). Удобно для
//  короткоживущих локальных списков внутри @pool, но такой список нельзя
//  хранить дольше пула. Для долгоживущих — явный `init(mem)` + `free()`.
//
//  ЗАДАЧА: исправьте объявление типа, распаковку `pop()` и утечку.
//  Ожидаемый вывод:
//      [3, 1, 4, 1, 5]
//      popped 5, popped 1, empty -> -1
//      [30, 10, 40]
//      [30, 40, 7]
//      sum = 77
//
import std::io;
import std::collections::list;

fn void main()
{
    @assert_leak()
    {
        List{int} nums;
        nums.init(mem);
        defer nums.free();

        nums.push(3);
        nums.push_all({ 1, 4, 1, 5 });
        io::printn(nums);
        assert(nums.len() == 5 && nums[2] == 4);

        int a = nums.pop() ?? -1;
        int b = nums.pop() ?? -1;

        List{int} empty;      // никогда не растёт — память не выделяется
        int c = empty.pop() ?? -1;
        io::printfn("popped %d, popped %d, empty -> %d", a, b, c);

        foreach (&x : nums) *x *= 10;
        io::printn(nums);

        nums.remove_at(1);
        nums.push(7);
        io::printn(nums);

        int sum;
        foreach (x : nums) sum += x;
        io::printfn("sum = %d", sum);
    };
}
