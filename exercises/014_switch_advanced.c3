// =====================================================================
//  014 · switch: nextcase, диапазоны и switch без выражения
// =====================================================================
//
//  NEXTCASE — ЯВНЫЙ ПРОВАЛ
//  Раз неявного провала в C3 нет, для него есть явная инструкция
//  `nextcase`: «продолжить со следующего case».
//
//      switch (level)
//      {
//          case 2:
//              io::printn("two");
//              nextcase;               // идём в case 1
//          case 1:
//              io::printn("one");
//      }
//
//  Можно и прыгнуть к конкретному значению: `nextcase 5;` — как если бы
//  switch заново вычислил выражение и получил 5. И к ветке по
//  умолчанию: `nextcase default;`. Так легко пишутся конечные автоматы.
//
//  ДИАПАЗОНЫ
//  `case 1..5:` — совпадает со значениями от 1 до 5 ВКЛЮЧИТЕЛЬНО.
//  Работает и для символов: `case 'a'..'z':`.
//
//  SWITCH БЕЗ ВЫРАЖЕНИЯ
//  Если после `switch` нет `(выражения)`, каждая метка — это условие
//  (bool), и выполняется первая ветка, чьё условие истинно. Это
//  аккуратная замена длинной цепочке `if / else if`:
//
//      switch
//      {
//          case x < 0:   io::printn("negative");
//          case x == 0:  io::printn("zero");
//          default:      io::printn("positive");
//      }
//
//  Порядок важен: условия проверяются сверху вниз.
//
//  ЗАДАЧА: исправьте три места с `// <-`. Программа должна напечатать:
//
//      95 -> A, 85 -> B, 72 -> C, 40 -> F
//      level 3 bonus: 111
//      level 1 bonus: 1
//      1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz
//
import std::io;

fn String grade(int score)
{
    switch (score)
    {
        case 90..100: return "A";
        case 80..89:  return "B";
        case ???:     return "C";           // <- оценки от 70 до 79
        default:      return "F";
    }
}

fn int bonus(int level)
{
    int total = 0;
    switch (level)
    {
        case 3:
            total += 100;                   // <- дальше должны выполниться case 2 и case 1
        case 2:
            total += 10;
            nextcase;
        case 1:
            total += 1;
    }
    return total;
}

fn void main()
{
    io::printfn("95 -> %s, 85 -> %s, 72 -> %s, 40 -> %s",
                grade(95), grade(85), grade(72), grade(40));
    io::printfn("level 3 bonus: %d", bonus(3));
    io::printfn("level 1 bonus: %d", bonus(1));

    for (int i = 1; i <= 15; i++)
    {
        switch
        {
            case i % 3 == 0:  io::print("Fizz");   // <- до этой ветки 15 не должно дойти
            case i % 5 == 0:  io::print("Buzz");
            case i % 15 == 0: io::print("FizzBuzz");
            default:          io::print(i);
        }
        io::print(i < 15 ? " " : "\n");
    }
}
