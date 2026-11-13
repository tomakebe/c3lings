// =====================================================================
//  072 · Generic-структуры и alias инстанцирований
// =====================================================================
//
//  Обобщёнными бывают не только функции, но и типы. Это основа любых
//  контейнеров: `List{int}`, `HashMap{String, int}` из стандартной
//  библиотеки, которыми вы уже пользовались, устроены именно так.
//
//  Параметры структуры пишутся после её имени:
//
//      struct Pair <First, Second>
//      {
//          First  first;
//          Second second;
//      }
//
//  Конкретный тип получается подстановкой параметров в `{...}`:
//
//      Pair{String, int} p = { "answer", 42 };
//
//  Каждый набор параметров даёт НОВЫЙ, отдельный тип: `Pair{int, int}`
//  и `Pair{int, long}` друг с другом не совместимы, у них разный размер,
//  разный typeid. А вот одинаковые наборы — это один и тот же тип, где бы
//  вы его ни написали.
//
//  Писать `Pair{String, int}` везде утомительно и шумно, поэтому
//  идиоматичный C3 даёт инстанцированиям имена через `alias`:
//
//      alias Score = Pair{String, int};
//      Score s = { "bob", 10 };
//
//  `alias` не создаёт новый тип — это просто второе имя. `Score` и
//  `Pair{String, int}` полностью взаимозаменяемы (сравните с `typedef`,
//  который создаёт отдельный тип).
//
//  Константные параметры. Параметром может быть целое (bool, enum)
//  значение — так задают размеры массивов во время компиляции:
//
//      struct Grid <Cell, W, H>
//      {
//          Cell[W * H] cells;
//      }
//      Grid{char, 4, 3} g;     // 12 байт, массив внутри структуры, без кучи
//
//  Это аналог `std::array<T, N>` в C++ или `fn Grid(comptime T: type,
//  comptime w: usize, ...) type` в Zig. В C пришлось бы копировать
//  структуру вручную или городить макросы-генераторы.
//
//  Generic-функции могут принимать и возвращать generic-структуры. Если
//  имена параметров совпадают, функция и структура инстанцируются
//  ВМЕСТЕ (подробнее — в следующем упражнении):
//
//      fn Pair{Second, First} swap_pair(Pair{First, Second} p) <First, Second>
//          => { p.second, p.first };
//
//  Обобщённым может быть и сам alias:
//
//      alias Twin <Type> = Type[2];
//      Twin{int} t = { 1, 2 };    // это просто int[2]
//
//  Рефлексия знает имя инстанцирования: `Score::name` — это строка
//  "Pair{String, int}". Удобно для отладки.
//
//  Напоминание: имена параметров-типов — `First`, `Cell`, `Value`, но не
//  `A`/`T` (всё заглавное — это константа).
//
//  ЗАДАЧА:
//    1. Объявите параметры структуры `Pair`.
//    2. Объявите `alias Score` — пара из имени (String) и очков (int).
//    3. Подберите параметры `Grid` в `main`, чтобы прошли проверки.
//
import std::io;

struct Pair <First, Second>
{
    First first;
    Second second;
}

alias Score = Pair{String, int};

struct Grid <Cell, W, H>
{
    Cell[W * H] cells;
}

fn Pair{Second, First} swap_pair(Pair{First, Second} p) <First, Second>
{
    return { p.second, p.first };
}

alias Twin <Type> = Type[2];

fn void main()
{
    Score s = { "bob", 10 };
    s.second += 5;
    io::printfn("%s has %d points", s.first, s.second);
    io::printfn("type name: %s", Score::name);

    Pair{double, bool} flag = { .first = 0.5, .second = true };
    io::printfn("%.1f %s", flag.first, flag.second);

    Pair{int, String} swapped = swap_pair{String, int}(s);
    io::printfn("swapped: %d %s", swapped.first, swapped.second);

    // Поле для крестиков-ноликов: 3 x 3 клетки по одному char.
    Grid{char, 3, 3} board;
    $assert $Typeof(board)::size == 9;
    assert(board.cells.len == 9);
    board.cells[4] = 'X';
    for (int y = 0; y < 3; y++)
    {
        for (int x = 0; x < 3; x++)
        {
            char c = board.cells[y * 3 + x];
            io::printf("%c", c ? c : '.');
        }
        io::printn();
    }

    Twin{int} t = { 1, 2 };
    io::printfn("%s is %s", Twin{int}::name, t);
}
