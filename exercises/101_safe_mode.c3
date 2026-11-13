// =====================================================================
//  101 · Safe и unchecked режимы, проверки границ
// =====================================================================
//
//  В C выход за границу массива, разыменование NULL, деление на ноль,
//  сдвиг на 40 бит — это неопределённое поведение (UB). Программа
//  может упасть, а может молча испортить соседние данные и упасть
//  через час в совершенно другом месте. Отлаживать такое — мучение.
//
//  C3 решает это двумя режимами сборки.
//
//  Safe mode (по умолчанию, а также -O0 и -O1)
//  -------------------------------------------
//  Компилятор вставляет проверки во время выполнения:
//
//      int[4] a;  a[6] = 1;
//        -> ERROR: 'Array index out of bounds (array had size 4, index was 6)'
//      int[] s = a[1:9];
//        -> ERROR: 'End index out of bounds ...'
//      int* p = null;  *p;
//        -> ERROR: 'Dereference of null pointer, 'p' was null.'
//      10 / z  (z == 0)
//        -> ERROR: 'Division by zero.'
//      1 << 35  (для int)
//        -> ERROR: 'Shift amount out of range (was 35).'
//      контракт <* @require n > 0 *> нарушен
//        -> ERROR: '@require "n > 0" violated.'
//      opt!!  с ошибкой внутри
//        -> ERROR: 'Unexpected fault 'io::EOF' was unwrapped!'
//      assert(cond), unreachable()
//
//  Паника печатает сообщение и стек вызовов (backtrace) в stderr и
//  завершает программу с ненулевым кодом. Ошибка обнаруживается В ТОМ
//  месте, где она случилась, а не там, где проявилась.
//
//  Unchecked mode (-O2 и выше, или явно --safe=no)
//  ------------------------------------------------
//  Все эти проверки исчезают, а assert и @require превращаются в
//  ПОДСКАЗКИ оптимизатору: «это всегда истинно». Если на самом деле
//  ложно — это снова UB, как в C, и даже хуже: компилятор мог
//  удалить код, «зная», что ветка невозможна. Программа из этого
//  упражнения, собранная с -O2, может не упасть, а молча напечатать
//  неверные числа — и это худший вариант.
//
//  Можно и комбинировать: `-O3 --safe=yes` — оптимизации с проверками.
//  Узнать режим в коде: `env::COMPILER_SAFE_MODE` (compile-time bool).
//
//  Что НЕ является ошибкой в C3 (в отличие от C):
//    * переполнение целых: int::max + 1 == int::min — определённое
//      заворачивание (wrap), без паники. Нужна проверка — делайте сами
//      или используйте sat_add;
//    * явное сужение `(char)300` — просто отбрасывает старшие биты (44).
//  Неинициализированных переменных нет вовсе: всё обнуляется, если не
//  написать `= void`.
//
//  Проверки можно обойти сознательно: индексация через сырой указатель
//  (`a.ptr[i]`) не проверяется — компилятор не знает длину. Это
//  «аварийный люк» для горячих циклов, где вы уверены в индексах.
//
//  Как работать: разрабатывайте и тестируйте в safe-режиме, релизную
//  сборку делайте unchecked (или оставьте safe — проверки обычно стоят
//  единицы процентов). В Zig есть то же самое: Debug/ReleaseSafe
//  против ReleaseFast; в Rust проверки границ есть всегда.
//
//  ЗАДАЧА: программа падает в safe-режиме. Запустите её
//  (`./c3lings run 101`), прочитайте сообщение о панике и номер строки,
//  почините ошибку, запустите снова. Ошибок четыре, и каждая — в логике
//  программы. Не отключайте проверки и не удаляйте контракты!
//
//  Ожидаемый вывод:
//      safe mode: true
//      students: 10, total: 714
//      histogram:
//        0- 9:
//       10-19:
//       20-29:
//       30-39: #
//       40-49: #
//       50-59: #
//       60-69: #
//       70-79: ##
//       80-89: ##
//       90-99: ##
//      group A: 66%
//      group B: 76%
//      group C: (empty)
//      id 104: Dmitry, 81
//      id 999: not found
//
import std::io;

struct Student
{
    int id;
    String name;
    int score;      // 0..100 включительно
    char group;
}

Student[10] students = {
    { 101, "Anna",    93, 'A' },
    { 102, "Boris",   45, 'B' },
    { 103, "Clara",   78, 'A' },
    { 104, "Dmitry",  81, 'B' },
    { 105, "Elena",  100, 'B' },
    { 106, "Fedor",   34, 'A' },
    { 107, "Galina",  67, 'B' },
    { 108, "Igor",    52, 'A' },
    { 109, "Kira",    89, 'B' },
    { 110, "Lev",     75, 'A' },
};

<*
 @require total > 0 : "percent of an empty set"
*>
fn int percent(int part, int total) => part * 100 / total;

fn Student* find_student(int id)
{
    foreach (&s : students)
    {
        if (s.id == id) return s;
    }
    return null;
}

fn void print_student(int id)
{
    Student* s = find_student(id);
    io::printfn("id %d: %s, %d", id, s.name, s.score);
}

fn void main()
{
    io::printfn("safe mode: %s", env::COMPILER_SAFE_MODE);

    int total = 0;
    for (usz i = 0; i <= students.len; i++) total += students[i].score;
    io::printfn("students: %d, total: %d", students.len, total);

    // 10 корзин: 0-9, 10-19, ..., 90-99. 100 баллов кладём в последнюю.
    int[10] buckets;
    foreach (s : students) buckets[s.score / 10]++;
    io::printn("histogram:");
    foreach (i, count : buckets)
    {
        io::printf("%3d-%2d: ", i * 10, i * 10 + 9);
        for (int k = 0; k < count; k++) io::print("#");
        io::printn();
    }

    foreach (char g : "ABC")
    {
        int sum = 0;
        int n = 0;
        foreach (s : students)
        {
            if (s.group != g) continue;
            sum += s.score;
            n++;
        }
        // средний балл в процентах от максимума (n * 100)
        io::printfn("group %c: %d%%", g, percent(sum, n * 100));
    }

    print_student(104);
    print_student(999);
}
