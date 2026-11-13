// =====================================================================
//  100 · Юнит-тесты: @test и c3c compile-test
// =====================================================================
//
//  Сотое упражнение! До сих пор каждая программа проверяла себя
//  assert'ами внутри main. В настоящих проектах проверки живут в
//  отдельных функциях-тестах, а запускает их тестовый раннер. В C3 он
//  встроен в компилятор — никаких внешних фреймворков (как и в Zig с
//  его `test "..." {}` или в Rust с #[test]).
//
//  Тест — это функция `fn void имя()` с атрибутом @test:
//
//      fn void test_add() @test
//      {
//          assert(add(2, 2) == 4);
//          test::eq(add(2, 2), 4);       // при провале печатает `5` != `4`
//      }
//
//  Запуск:
//      c3c compile-test file1.c3 file2.c3   — для отдельных файлов
//      c3c test                             — для проекта (project.json)
//  Полезные флаги: --test-filter <подстрока> (запустить только часть),
//  --test-show-output (не прятать вывод тестов), --test-noleak.
//
//  Раннер находит все @test-функции, запускает каждую и печатает
//  PASS/FAIL. Если что-то провалилось — код выхода ненулевой (это
//  удобно в CI). main при этом не нужен (и не вызывается). Тесты
//  можно класть прямо рядом с кодом — в обычной сборке (compile/build)
//  @test-функции просто не попадают в программу.
//
//  Модуль std::core::test (доступен как test::...) даёт проверки с
//  понятными сообщениями:
//
//      test::eq(a, b)     test::ne(a, b)
//      test::lt / le / gt / ge
//      test::eq_approx(x, 0.333, places: 3)     // для double
//      test::@check(cond, "fmt %d", x)          // assert с сообщением
//      test::@error(f(x))                       // f(x) должен вернуть ошибку
//      test::@error(f(x), MY_ERROR)             // ...и именно эту
//
//  Не забывайте и про Optional: `f(x)!!` в тесте — «должно быть
//  значение, иначе паника», а паника = проваленный тест.
//
//  Бесплатный бонус: детектор утечек. Тестовый раннер оборачивает
//  каждый тест в отслеживающий аллокатор, и если тест выделил память
//  через `mem` и не освободил — тест ПРОВАЛЕН с отчётом, где была
//  выделена утёкшая память. Так утечки ловятся сразу, а не через
//  месяц в продакшене. (Отключается флагом --test-noleak.)
//
//  Хорошие тесты:
//    * проверяют граничные случаи: пустой ввод, 0, максимум, ошибки;
//    * маленькие и независимые (порядок запуска не гарантирован);
//    * имеют говорящие имена: test_parse_rejects_empty, а не test3.
//
//  Это упражнение запускается раннером через `c3c compile-test`
//  (файл checks/100_unit_tests.mode). Успех = все тесты прошли.
//  Посмотреть результат: ./c3lings run 100.
//
//  ЗАДАЧА: тесты уже написаны и находят ошибки в коде.
//    1. Почините clamp и parse_uint, чтобы тесты прошли (тесты
//       менять нельзя — они правы!).
//    2. Замените ??? в test_parse_errors нужной ошибкой.
//    3. Почините утечку памяти в test_repeat.
//
module textutil;

excuse EMPTY_INPUT, BAD_DIGIT, TOO_BIG;

<*
 Ограничить v диапазоном [lo, hi].
*>
fn int clamp(int v, int lo, int hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

<*
 Разобрать неотрицательное десятичное число, не больше 1_000_000.
*>
fn int? parse_uint(String s)
{
    if (s.len == 0) return EMPTY_INPUT~;
    int result = 0;
    foreach (c : s)
    {
        if (c < '0' || c > '9') return BAD_DIGIT~;
        result = result * 10 + (c - '0');
        if (result > 1_000_000) return TOO_BIG~;
    }
    return result;
}

<*
 Повторить строку n раз. Память выделяется из allocator, освобождает вызывающий.
*>
fn String repeat(Allocator allocator, String s, int n)
{
    char[] buf = alloc::new_array(allocator, char, s.len * n);
    for (int i = 0; i < n; i++) buf[i * s.len : s.len] = s[..];
    return (String)buf;
}

// ------------------------------------------------------------- тесты

fn void test_clamp() @test
{
    test::eq(clamp(5, 0, 10), 5);
    test::eq(clamp(-3, 0, 10), 0);
    test::eq(clamp(42, 0, 10), 10);
    test::eq(clamp(10, 0, 10), 10);
}

fn void test_parse_ok() @test
{
    test::eq(parse_uint("0")!!, 0);
    test::eq(parse_uint("12345")!!, 12345);
    test::eq(parse_uint("1000000")!!, 1_000_000);
}

fn void test_parse_errors() @test
{
    test::@error(parse_uint(""), EMPTY_INPUT);
    test::@error(parse_uint("12a"), BAD_DIGIT);
    test::@error(parse_uint("1000001"), TOO_BIG);
}

fn void test_repeat() @test
{
    String r = repeat(mem, "ab", 3);
    defer r.free(mem);
    test::eq(r, "ababab");
    test::eq(r.len, 6);
}
