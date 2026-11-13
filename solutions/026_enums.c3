// =====================================================================
//  026 · Перечисления (enum)
// =====================================================================
//
//      enum Direction
//      {
//          NORTH,
//          EAST,
//          SOUTH,
//          WEST,
//      }
//
//  Значения пишутся ЗАГЛАВНЫМИ. Полное имя — `Direction.NORTH`, но там,
//  где тип понятен из контекста (присваивание, аргумент функции,
//  `case`), имя типа можно опустить: `Direction d = NORTH;`.
//
//  ОТЛИЧИЯ ОТ C
//  * enum в C3 — это настоящий отдельный тип, а не набор int-констант.
//    Неявно в число и обратно он не превращается.
//  * Значения всегда идут подряд: 0, 1, 2, ... Задать `NORTH = 5` нельзя
//    (для произвольных значений есть `constset` — упражнение 047).
//    Номер значения называется ORDINAL.
//  * `%s` печатает ИМЯ значения: "NORTH".
//
//  СВОЙСТВА
//      d.ordinal                   номер значения (int)
//      Direction::from_ordinal(i)  значение по номеру (с проверкой
//                                  границ в отладочной сборке)
//      Direction::len              количество значений (sz)
//      Direction::values           все значения (можно обойти foreach)
//      Direction::names            их имена в виде строк
//  Свойства ТИПА пишутся через `::`, свойства ЗНАЧЕНИЯ — через точку.
//  Также работает приведение: `(int)d`, `(Direction)2`.
//
//  SWITCH ПО ENUM ДОЛЖЕН БЫТЬ ПОЛНЫМ
//  Если в `switch` по enum нет `default`, компилятор требует, чтобы были
//  перечислены ВСЕ значения: "Enum value WEST was not handled in the
//  switch". Добавили в enum новое значение — компилятор покажет все
//  места, которые нужно обновить. Поэтому `default` для enum лучше не
//  писать без необходимости.
//
//  ЗАДАЧА: исправьте три места с `// <-`. Программа должна напечатать:
//
//      NORTH (0) -> ^
//      EAST (1) -> >
//      SOUTH (2) -> v
//      WEST (3) -> <
//      turn right from WEST: NORTH
//      4 directions: [NORTH, EAST, SOUTH, WEST]
//
import std::io;

enum Direction
{
    NORTH,
    EAST,
    SOUTH,
    WEST,
}

fn String arrow(Direction d)
{
    switch (d)                                        // <- не все значения обработаны
    {
        case NORTH: return "^";
        case EAST:  return ">";
        case SOUTH: return "v";
        case WEST:  return "<";
    }
}

fn Direction turn_right(Direction d)
{
    int next = (d.ordinal + 1) % (int)Direction::len;
    return Direction::from_ordinal(next);
}

fn void main()
{
    foreach (d : Direction::values)
    {
        io::printfn("%s (%d) -> %s", d, d.ordinal, arrow(d));
    }
    io::printfn("turn right from WEST: %s", turn_right(WEST));
    io::printfn("%d directions: %s", Direction::len, Direction::names);
}
