// =====================================================================
//  067 · Сортировка и компараторы
// =====================================================================
//
//  Модуль `std::sort` даёт generic-макросы сортировки (они @builtin —
//  вызываются без префикса):
//
//      quicksort(list)              быстрая, НЕ устойчивая
//      mergesort(list)              устойчивая (равные элементы сохраняют
//                                   исходный порядок), берёт буфер из tmem
//      insertionsort(list)          простая, хороша для маленьких массивов
//      is_sorted(list)              проверка
//      binarysearch(list, x)        индекс x в ОТСОРТИРОВАННОМ массиве
//                                   (или место, куда его вставить)
//
//  Что можно сортировать:
//    * срез: `quicksort(arr[..])` или просто `quicksort(slice)`;
//    * массив или List — по УКАЗАТЕЛЮ: `quicksort(&arr)`, `quicksort(&list)`.
//      Передать List по значению нельзя — сортировалась бы копия, и
//      компилятор это запрещает контрактом.
//
//  Без компаратора элементы сравниваются встроенным `compare_to(a, b)`:
//  числа и строки — естественно, свои типы — через `<` и `==` (063).
//
//  Свой порядок задаёт КОМПАРАТОР — функция, возвращающая ЦЕЛОЕ:
//      < 0   если a должен идти раньше b,
//      0     если равны,
//      > 0   если a должен идти позже b.
//  (как у qsort в C; именно int, не bool — `a < b` здесь не подойдёт).
//
//      fn int by_age(Person a, Person b) => compare_to(a.age, b.age);
//      quicksort(people, &by_age);
//
//  Параметры можно принимать и по указателю (`Person* a, Person* b`) —
//  для больших структур это дешевле. Лямбда тоже подходит:
//      quicksort(nums, fn int(int a, int b) => compare_to(b, a)); // по убыванию
//
//  Удобные помощники для компараторов: `compare_to(x, y)` для чисел
//  и `s1.compare_to(s2)` для строк. Сортировка по нескольким ключам:
//  сравнить первый; если 0 — сравнить второй.
//
//  ЗАДАЧА: исправьте компаратор, сортировку List'а и порядок по
//  нескольким ключам. Ожидаемый вывод:
//      by age: dave(25) alice(25) bob(30) carol(35)
//      by name: alice bob carol dave
//      scores desc: 99 87 64 42 15
//      ranking: carol alice bob dave
//
import std::io;
import std::sort;
import std::collections::list;

struct Person
{
    String name;
    int age;
    int score;
}

fn int by_age(Person a, Person b) => compare_to(a.age, b.age);

fn int by_name(Person* a, Person* b) => a.name.compare_to(b.name);

// Сначала по очкам (больше — выше), при равенстве очков — по имени.
fn int by_ranking(Person* a, Person* b)
{
    int c = compare_to(b.score, a.score);
    if (c != 0) return c;
    return a.name.compare_to(b.name);
}

fn void main()
{
    Person[] people = {
        { "dave", 25, 70 },
        { "carol", 35, 90 },
        { "alice", 25, 80 },
        { "bob", 30, 80 },
    };

    // mergesort устойчив: dave и alice (оба 25) сохранят исходный порядок
    mergesort(people, &by_age);
    io::print("by age:");
    foreach (p : people) io::printf(" %s(%d)", p.name, p.age);
    io::printn();

    quicksort(people, &by_name);
    io::print("by name:");
    foreach (p : people) io::printf(" %s", p.name);
    io::printn();

    @pool()
    {
        List{int} scores;
        scores.push_all({ 42, 99, 15, 87, 64 });
        quicksort(&scores, fn int(int a, int b) => compare_to(b, a));
        io::print("scores desc:");
        foreach (x : scores) io::printf(" %d", x);
        io::printn();
    };

    quicksort(people, &by_ranking);
    io::print("ranking:");
    foreach (p : people) io::printf(" %s", p.name);
    io::printn();
}
