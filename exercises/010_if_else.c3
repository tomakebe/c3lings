// =====================================================================
//  010 · if / else, тернарный оператор и elvis
// =====================================================================
//
//  `if` выглядит как в C:
//
//      if (hp <= 0)
//      {
//          io::printn("game over");
//      }
//      else if (hp < 10)
//      {
//          io::printn("low hp");
//      }
//      else
//      {
//          io::printn("ok");
//      }
//
//  Условие — bool. Целые числа и указатели тоже допускаются (сравниваются
//  с нулём / null), но bool нагляднее.
//
//  ФИГУРНЫЕ СКОБКИ
//  Без `{ }` можно обойтись, только если тело на ТОЙ ЖЕ строке, что и
//  `if`:
//
//      if (x < 0) return -x;          // можно
//
//      if (x < 0)
//          return -x;                 // ОШИБКА в C3
//
//  Это защита от классической ошибки C: человек добавляет вторую строку
//  с тем же отступом и думает, что она тоже внутри `if`.
//
//  ТЕРНАРНЫЙ ОПЕРАТОР — как в C: `условие ? если_да : если_нет`.
//
//      String s = n > 0 ? "positive" : "not positive";
//
//  ELVIS `?:` — сокращение для «значение, а если оно "пустое" —
//  запасное»:
//
//      a ?: b      то же, что   a ? a : b   (но `a` вычисляется один раз)
//
//  «Пустое» значение — это 0, false, null или пустая строка "". Удобно
//  для значений по умолчанию:
//
//      int lives = saved_lives ?: 3;      // если сохранено 0 — даём 3
//
//  ЗАДАЧА: исправьте три места с `// <-`. Программа должна напечатать:
//
//      -5 -> freezing
//      12 -> cold
//      25 -> warm
//      lives: 3
//      player: anonymous
//      7 is odd
//      10 is even
//
import std::io;

fn String classify(int temp)
{
    if (temp < 0)
        return "freezing";                     // <- тело на другой строке без { }
    else if (temp < 20)
    {
        return "cold";
    }
    return "warm";
}

fn String parity(int n)
{
    return ???;                                // <- тернарный оператор: "even" или "odd"
}

fn void main()
{
    io::printfn("-5 -> %s", classify(-5));
    io::printfn("12 -> %s", classify(12));
    io::printfn("25 -> %s", classify(25));

    int saved_lives = 0;
    int lives = saved_lives ?: 3;
    io::printfn("lives: %d", lives);

    String nickname = "";
    String shown = nickname ??? "anonymous";   // <- оператор «значение или запасное»
    io::printfn("player: %s", shown);

    io::printfn("7 is %s", parity(7));
    io::printfn("10 is %s", parity(10));
}
