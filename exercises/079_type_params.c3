// =====================================================================
//  079 · Параметры-типы `$Type` и compile-time параметры
// =====================================================================
//
//  Параметр макроса, начинающийся со знака `$`, — это параметр ВРЕМЕНИ
//  КОМПИЛЯЦИИ. Он бывает двух видов:
//
//    * `$Type` (имя в стиле типа) — сюда передаётся сам ТИП:
//
//          macro usz bits_of($Type) => $Type::size * 8;
//          bits_of(int);      // 32
//          bits_of(char);     // 8
//
//      В C для этого приходилось писать `#define BITS(T) (sizeof(T)*8)`,
//      в C++ — `template <typename T> constexpr size_t bits_of()` и
//      вызывать `bits_of<int>()`. В Zig — `fn bitsOf(comptime T: type)`.
//      В C3 тип — просто аргумент, но только у макросов.
//
//    * `$name` (имя в стиле переменной) — значение, которое обязано быть
//      константой времени компиляции:
//
//          macro make_filled($Type, int $n, value)
//          {
//              $Type[$n] arr;     // размер массива — константа, ok
//              ...
//          }
//          make_filled(double, 4, 0.5);   // double[4]
//          int n = 4;
//          make_filled(double, n, 0.5);   // ОШИБКА: n — не константа
//
//  Что можно делать с `$Type` внутри макроса — всё, что с обычным типом:
//  объявлять переменные (`$Type x;`), приводить (`($Type)v`), спрашивать
//  свойства: `$Type::size`, `$Type::alignment`, `$Type::name`,
//  `$Type::min`, `$Type::max`, `$Type::kind`, `$Type::typeid`.
//
//  `$`-параметры — не магия в смысле предыдущего упражнения: они не
//  меняют переменных вызывающего и не откладывают вычисления, поэтому
//  макросу с ними НЕ нужен `@` в имени. (Сравните: `mem::new(Foo)` или
//  `mem::new_array(int, n)` из std — это как раз макросы с `$Type`.)
//
//  Отличие от generic-функций: `fn Type f(...) <Type>` вызывается как
//  `f{int}(...)` и порождает настоящую функцию; макрос с `$Type`
//  встраивается в место вызова, а тип передаётся прямо в скобках
//  вместе с остальными аргументами — удобнее для мелких утилит.
//
//  Макрос, у которого ВСЕ параметры compile-time, а тело — только
//  `return`, целиком вычисляется при компиляции и может инициализировать
//  константы:
//
//      macro bool is_pow2(int $n) => $n > 0 && ($n & ($n - 1)) == 0;
//      const bool OK = is_pow2(64);
//
//  ЗАДАЧА:
//    1. Допишите параметр `bits_of`.
//    2. Реализуйте `range_text`: строка вида "short: -32768..32767"
//       (используйте `$Type::name`, `$Type::min`, `$Type::max` и
//       `string::tformat`).
//    3. Реализуйте `make_filled`: массив `$Type[$n]`, все элементы
//       которого равны `value` (приведённому к `$Type`).
//
import std::io;

macro usz bits_of(???) => $Type::size * 8;

macro String range_text($Type)
{
    return "TODO";
}

macro make_filled($Type, int $n, value)
{
    // TODO: создайте массив $Type[$n], заполните его value и верните.
    $Type[$n] arr;
    return arr;
}

macro bool is_pow2(int $n) => $n > 0 && ($n & ($n - 1)) == 0;

const bool PAGE_OK = is_pow2(4096);

fn void main()
{
    assert(bits_of(int) == 32);
    assert(bits_of(ulong) == 64);
    io::printfn("bits: char=%d short=%d int=%d long=%d",
                bits_of(char), bits_of(short), bits_of(int), bits_of(long));

    @pool()
    {
        String r = range_text(short);
        assert(r == "short: -32768..32767");
        io::printn(r);
        io::printn(range_text(ichar));
        io::printn(range_text(ushort));
    };

    double[4] halves = make_filled(double, 4, 0.5);
    io::printfn("%s", halves);
    int[3] sevens = make_filled(int, 3, 7);
    assert(sevens[0] == 7 && sevens[2] == 7);
    io::printfn("%s (%s)", sevens, $Typeof(sevens)::name);

    $assert PAGE_OK;
    $assert !is_pow2(100);
    io::printfn("4096 is power of two: %s", PAGE_OK);
}
