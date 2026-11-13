// =====================================================================
//  049 · Вариадические функции: `int...` и `any...`
// =====================================================================
//
//  В C вариадические функции (`printf(const char*, ...)`) опасны:
//  функция не знает ни количества, ни типов аргументов и доверяет
//  форматной строке. Ошибся — неопределённое поведение.
//
//  В C3 есть безопасные варианты.
//
//  1) ТИПИЗИРОВАННЫЕ: все аргументы одного типа.
//
//      fn int sum(int... nums)       // внутри nums — это срез int[]
//      {
//          int s;
//          foreach (n : nums) s += n;
//          return s;
//      }
//      sum();            // 0 аргументов — пустой срез
//      sum(1, 2, 3);
//
//     Обычные параметры могут стоять перед вариадическим:
//     `fn int max_of(int first, int... rest)` — минимум один аргумент.
//
//  2) SPLAT `...` — «распаковать» массив или срез в аргументы:
//
//      int[4] arr = { 1, 2, 3, 4 };
//      sum(...arr);              // как sum(1, 2, 3, 4)
//      sum(...arr[1..2], 10);    // как sum(2, 3, 10)
//
//     Просто `sum(arr)` не сработает: функция ждёт int'ы, а не массив.
//
//  3) РАЗНОТИПНЫЕ: `any...`. `any` — это пара «указатель + typeid»:
//     значение плюс информация о его типе во время выполнения.
//
//      fn void show(any... args)
//      {
//          foreach (a : args)
//          {
//              switch (a.type)        // switch по типу!
//              {
//                  case int:    io::printf("%d ", *(int*)a);
//                  case String: io::printf("%s ", *(String*)a);
//                  default:     io::print("? ");
//              }
//          }
//      }
//      int x = 5;
//      show(&x, &&"hi");   // передаём АДРЕСА: & переменной, && временного
//
//     Внутри case тип проверен, и приводить `any` к указателю на этот
//     тип безопасно. Именно так устроен `io::printfn` — поэтому он
//     и не может «ошибиться» в типе, как printf в C. (Есть ещё форма
//     `fn void f(args...)`, где адреса берутся неявно, и `extern fn
//     void f(...)` — только для C-функций. Подробнее об any — в 058.)
//
//  ЗАДАЧА: почините четыре места, помеченные `// <-`.
//
import std::io;

fn int sum(int... nums) // <- функция должна принимать любое число int'ов
{
    int s;
    foreach (n : nums) s += n;
    return s;
}

fn int max_of(int first, int... rest)
{
    int m = first;
    foreach (n : rest) if (n > m) m = n;
    return m;
}

fn void describe(String label, any... values)
{
    io::printf("%s:", label);
    foreach (v : values)
    {
        switch (v.type)
        {
            case int: io::printf(" int %d", *(int*)v);
            case String: io::printf(" string '%s'", *(String*)v); // <- какой тип?
            case bool: io::printf(" bool %s", *(bool*)v);
            default: io::print(" unknown");
        }
    }
    io::printn();
}

fn void main()
{
    io::printfn("sum() = %d", sum());
    io::printfn("sum(1, 2, 3) = %d", sum(1, 2, 3));

    int[5] scores = { 7, 3, 9, 1, 5 };
    int total = sum(...scores); // <- распакуйте массив в аргументы
    io::printfn("total = %d, max = %d", total, max_of(...scores));
    assert(total == 25);

    int hp = 42;
    String name = "orc";
    bool angry = true;
    describe("monster", &name, &hp, &angry); // <- в any... передаются адреса
    describe("misc", &&1.5, &&7);
}
