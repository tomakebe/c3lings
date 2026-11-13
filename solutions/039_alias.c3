// =====================================================================
//  039 · `alias`: синонимы типов, функций, указателей на функции
// =====================================================================
//
//  `alias` даёт ещё одно имя чему-то уже существующему. Синтаксис
//  всегда один: `alias НовоеИмя = старое;`
//
//      alias Score    = int;              // синоним типа
//      alias Row      = int[4];           // синоним составного типа
//      alias Callback = fn void(int);     // тип указателя на функцию
//      alias say      = io::printn;       // синоним функции (или макроса)
//      alias MAX_HP   = LIMIT;            // синоним константы/глобальной
//
//  В C для этого служили `typedef` и `#define`. В C3 `typedef` — это
//  совсем другое (новый отдельный тип, см. 040), а `alias` — ровно
//  «другое имя»: `Score` и `int` — ОДИН И ТОТ ЖЕ тип, они свободно
//  смешиваются, и `Score::size` == `int::size`.
//
//  Соглашение об именах (компилятор его проверяет!): синонимы типов
//  пишутся с заглавной буквы (`Score`), синонимы функций и переменных —
//  со строчной (`say`), констант — ЗАГЛАВНЫМИ.
//
//  Указатели на функции в C3 записываются ТОЛЬКО через alias. Тип
//  получается из объявления функции, если выкинуть её имя:
//
//      fn int square(int x)    ->    fn int(int x)   (имя параметра можно опустить)
//
//      alias IntFn = fn int(int);
//      IntFn f = &square;     // адрес функции берётся явно через &
//      int y = f(5);          // вызов как у обычной функции
//
//  В отличие от C, просто `square` без `&` в качестве значения
//  использовать нельзя — компилятор попросит `&square`.
//
//  Синонимы функций полезны, чтобы сократить длинное имя из другого
//  модуля или дать функции имя по смыслу, не создавая обёртку.
//
//  ЗАДАЧА: почините три места, помеченные `// <-`.
//
import std::io;

alias Row = int[4];
alias IntFn = fn int(int); // <- тип «функция, принимающая int и возвращающая int»
alias say = io::printn;    // <- синоним для io::printn

fn int square(int x) => x * x;
fn int negate(int x) => -x;

// Принимает обычный int[4] — и Row подходит, это тот же тип.
fn int sum(int[4] values)
{
    int total;
    foreach (v : values) total += v;
    return total;
}

fn Row map(Row row, IntFn f)
{
    Row result;
    foreach (i, v : row) result[i] = f(v);
    return result;
}

fn void main()
{
    Row row = { 1, 2, 3, 4 };
    assert(Row::size == int::size * 4);

    Row squares = map(row, &square); // <- передаём адрес функции
    IntFn f = &negate;
    Row negated = map(row, f);

    say("squares and negated:");
    io::printfn("%s sum=%d", squares, sum(squares));
    io::printfn("%s sum=%d", negated, sum(negated));
    assert(sum(squares) == 30 && sum(negated) == -10);
}
