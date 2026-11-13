// =====================================================================
//  011 · while, do-while и do-блок
// =====================================================================
//
//  WHILE — проверяет условие ПЕРЕД каждой итерацией (может не
//  выполниться ни разу):
//
//      while (n > 0)
//      {
//          n--;
//      }
//
//  DO-WHILE — проверяет условие ПОСЛЕ итерации, поэтому тело
//  выполняется хотя бы один раз. Как и в C, после `while (...)` нужна
//  точка с запятой:
//
//      do
//      {
//          tries++;
//      } while (tries < 3);
//
//  `break` выходит из цикла, `continue` переходит к следующей проверке
//  условия.
//
//  DO-БЛОК БЕЗ WHILE — особенность C3. Это блок, который выполняется
//  ровно один раз, но из него можно выйти по `break`:
//
//      do
//      {
//          if (x < 0) { error = "negative"; break; }
//          if (x > 100) { error = "too big"; break; }
//          error = "none";
//      };              // <- точка с запятой ОБЯЗАТЕЛЬНА
//
//  Это заменяет сишный приём `do { ... } while (0)` и многие случаи,
//  где в C писали `goto`: цепочка проверок, после первой неудачной —
//  выход. Без `;` компилятор решит, что вы забыли `while`
//  ("Expected 'while'").
//
//  ЗАДАЧА: исправьте места с `// <-`. Программа должна напечатать:
//
//      collatz(6) takes 8 steps
//      menu shown 1 time(s)
//      age -5: negative
//      age 200: too old
//      age 30: valid
//
import std::io;

// Гипотеза Коллатца: если n чётное — делим на 2, иначе n = 3n + 1.
// Считаем шаги, пока не дойдём до 1.
fn int collatz_steps(int n)
{
    int steps = 0;
    while (n != 1)
    {
        if (n % 2 == 0)
        {
            n = n / 2;
        }
        else
        {
            n = 3 * n + 1;
        }
        steps++;
    }
    return steps;
}

fn String check_age(int age)
{
    String status;
    do
    {
        if (age < 0)
        {
            status = "negative";
            break;
        }
        if (age > 150)
        {
            status = "too old";
            break;
        }
        status = "valid";
    };
    return status;
}

fn void main()
{
    io::printfn("collatz(6) takes %d steps", collatz_steps(6));

    int shown = 0;
    bool want_more = false;
    do
    {
        shown++;                        // тело выполнится хотя бы раз
    } while (want_more);
    io::printfn("menu shown %d time(s)", shown);

    io::printfn("age -5: %s", check_age(-5));
    io::printfn("age 200: %s", check_age(200));
    io::printfn("age 30: %s", check_age(30));
}
