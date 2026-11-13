// =====================================================================
//  085 · Вычисления во время компиляции
// =====================================================================
//
//  Если у макроса ВСЕ параметры — compile-time (`$`), а тело состоит
//  только из compile-time конструкций (`$if`, `$for`, `$`-переменные) и
//  `return`, то он целиком вычисляется компилятором. Результат — обычная
//  константа, которой можно инициализировать `const`:
//
//      macro long @fib(long $n)
//      {
//          $if $n <= 1:
//              return $n;
//          $else
//              return @fib($n - 1) + @fib($n - 2);   // рекурсия!
//          $endif
//      }
//      const long FIB20 = @fib(20);     // в бинарнике просто 6765
//
//  Обратите внимание: `$n`, а не `n`. Условие `n <= 1` компилятор не
//  считает константным, даже если передали литерал — это сознательное
//  ограничение: вы ЯВНО отмечаете, что вычисляется при компиляции.
//
//  Внутри такого макроса можно заводить изменяемые compile-time
//  переменные и гонять по ним `$for`:
//
//      var $acc = 1L;
//      $for var $i = 2; $i <= $n; $i++:
//          $acc *= $i;
//      $endfor
//      return $acc;
//
//  Compile-time переменная может хранить и МАССИВ. Оператор `+++`
//  склеивает массивы (и строки) при компиляции, а также добавляет
//  элемент в конец:
//
//      uint[] $t = {};
//      $t = $t +++ 42u;          // { 42 }
//      $t = $t +++ (uint[]){ 1, 2 };
//
//  Так строят ТАБЛИЦЫ ПОИСКА: синусы, CRC, раскладки битов. В C их
//  либо считают при старте программы, либо генерируют скриптом и
//  вставляют в исходник километровым литералом. В C++ — `constexpr`
//  функции, в Zig — `comptime` блоки. В C3 — макрос с `$`-кодом.
//
//  Пределы: compile-time вычисления медленнее обычного кода и
//  ограничены глубиной рекурсии макросов. Для действительно тяжёлой
//  генерации C3 советует `$exec` (запуск скрипта при сборке) или
//  `$embed` (вставка файла). Для таблиц на сотни-тысячи элементов —
//  макросы в самый раз.
//
//  Ниже — CRC-32 (тот самый, что в zip/png). Классическая реализация
//  использует таблицу из 256 чисел; `@crc_entry(i)` уже считает одно
//  её значение при компиляции.
//
//  ЗАДАЧА:
//    1. Реализуйте `@factorial` через `$for` и compile-time переменную.
//    2. Реализуйте `@crc_table`: массив из 256 элементов
//       `@crc_entry(0)`, ..., `@crc_entry(255)`, собранный через `+++`.
//
import std::io;

macro long @fib(long $n)
{
    $if $n <= 1:
        return $n;
    $else
        return @fib($n - 1) + @fib($n - 2);
    $endif
}

macro long @factorial(long $n)
{
    var $acc = 1L;
    $for var $i = 2; $i <= $n; $i++:
        $acc *= $i;
    $endfor
    return $acc;
}

macro uint @crc_entry(uint $n)
{
    var $c = $n;
    $for var $k = 0; $k < 8; $k++:
        $c = ($c & 1) ? 0xEDB88320 ^ ($c >> 1) : $c >> 1;
    $endfor
    return $c;
}

macro @crc_table()
{
    uint[] $t = {};
    $for var $i = 0; $i < 256; $i++:
        $t = $t +++ @crc_entry($i);
    $endfor
    return $t;
}

const long FIB20 = @fib(20);
const long FACT10 = @factorial(10);
const uint[256] CRC_TABLE = @crc_table();

$assert FIB20 == 6765;
$assert FACT10 == 3628800 : "factorial is wrong";
$assert @factorial(0) == 1 && @factorial(1) == 1;

fn uint crc32(char[] data)
{
    uint c = 0xFFFFFFFF;
    foreach (b : data) c = CRC_TABLE[(c ^ b) & 0xFF] ^ (c >> 8);
    return c ^ 0xFFFFFFFF;
}

fn void main()
{
    io::printfn("fib(20)     = %d", FIB20);
    io::printfn("10!         = %d", FACT10);
    io::printfn("table[1]    = %08x", CRC_TABLE[1]);
    io::printfn("table[255]  = %08x", CRC_TABLE[255]);
    uint h = crc32("hello");
    assert(h == 0x3610a686);
    io::printfn("crc(hello)  = %08x", h);
    io::printfn("crc(C3)     = %08x", crc32("C3"));
}
