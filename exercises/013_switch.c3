// =====================================================================
//  013 · switch: основы
// =====================================================================
//
//  `switch` похож на сишный, но с важным отличием: после каждого `case`
//  стоит НЕЯВНЫЙ `break`. Провала (fallthrough) в следующий `case` нет:
//
//      switch (x)
//      {
//          case 1:
//              io::printn("one");      // и всё, дальше не идём
//          case 2:
//              io::printn("two");
//          default:
//              io::printn("other");
//      }
//
//  В C забытый `break` — одна из самых частых ошибок. Здесь его не
//  нужно писать вовсе (хотя `break` внутри case и разрешён — он просто
//  выходит из switch досрочно).
//
//  НЕСКОЛЬКО МЕТОК НА ОДНУ ВЕТКУ
//  ПУСТОЙ `case` (без инструкций) проваливается в следующий. Так
//  несколько значений объединяются в одну ветку:
//
//      case 'a':
//      case 'e':
//      case 'i':
//          vowels++;               // для 'a', 'e' и 'i'
//
//  Обратная сторона: если вы хотите, чтобы какой-то case НИЧЕГО не
//  делал, оставить его пустым нельзя — он провалится дальше! Напишите
//  в нём хотя бы `break;`.
//
//  Перечислить значения через запятую (`case 1, 2:`) нельзя.
//
//  `switch` в C3 работает не только с целыми и символами, но и со
//  строками (`case "move":`) — сравнивается содержимое.
//
//  ЗАДАЧА: подсчёт букв в фразе. Гласными считаем a, e, i, o, u; букву
//  'y' вообще не считаем; пробелы считаем отдельно; остальное —
//  согласные. Исправьте места с `// <-`. Программа должна напечатать:
//
//      vowels=11 spaces=8 consonants=23
//      move costs 1
//      attack costs 3
//      dance costs 0
//
import std::io;

fn int cost(String command)
{
    switch (command)
    {
        case "move":
            return 1;
        case "attack":
            return 3;
        default:
            return 0;
    }
}

fn void main()
{
    String text = "the quick brown fox jumps over the lazy dog";
    int vowels = 0;
    int spaces = 0;
    int consonants = 0;

    for (int i = 0; i < text.len; i++)
    {
        switch (text[i])
        {
            case 'a':                       // <- добавьте остальные гласные
                vowels++;
            case 'y':                       // <- 'y' не должна ни во что попадать
            case ' ':
                spaces++;
            default:
                consonants++;
        }
    }

    io::printfn("vowels=%d spaces=%d consonants=%d", vowels, spaces, consonants);
    io::printfn("move costs %d", cost("move"));
    io::printfn("attack costs %d", cost("attack"));
    io::printfn("dance costs %d", cost("dance"));
}
