// =====================================================================
//  083 · `$defined`, `$assert`, `$error`, `$echo`
// =====================================================================
//
//  Четыре инструмента, которые делают compile-time код надёжным.
//
//  `$assert` — статическая проверка (как `static_assert` в C11/C++).
//  Если условие ложно, программа просто не скомпилируется:
//
//      $assert Header::size == 8 : "Header must be exactly 8 bytes";
//      $assert(int::size == 4);              // скобочная форма тоже есть
//
//  Это одна из немногих compile-time конструкций, разрешённых на
//  ВЕРХНЕМ уровне файла. Классика: зафиксировать раскладку структуры,
//  которая пишется в файл или передаётся по сети — если кто-то потом
//  добавит поле или сменит тип, сборка сломается сразу, а не данные
//  у пользователей. Обычный `assert` проверяет только при запуске (и
//  только если до него дошли).
//
//  `$defined(...)` — «а это вообще скомпилируется?» Возвращает true/false
//  во время компиляции:
//
//      $defined(Foo)            // есть ли такой тип/идентификатор
//      $defined(x.len)          // есть ли у x поле или метод len
//      $defined(x.area())       // можно ли вызвать x.area() без аргументов
//      $defined(int v = expr)   // можно ли инициализировать int этим
//      $defined(a + b)          // определён ли оператор + для a и b
//
//  Это «утиная типизация» для макросов: «если у значения есть метод
//  `area` — вызову его, иначе сделаю что-то другое». В C++ для этого
//  нужен SFINAE или `requires`, в Zig — `@hasDecl`/`@hasField`.
//
//  Важно: `$defined` проверяет, ВАЛИДНО ли выражение, но выражение
//  должно быть синтаксически правильным — мусор внутри будет ошибкой,
//  а не `false`. И, как вы видели в 074, нарушенный контракт generic'а
//  `$defined` тоже не «ловит».
//
//  `$error "сообщение"` — безусловная ошибка компиляции. Ставят в ту
//  ветку `$if`/`$switch`, которая «не должна случаться»: так вместо
//  невнятной ошибки в глубине макроса пользователь увидит ваше
//  понятное сообщение. Строки можно склеивать compile-time
//  конкатенацией `+++`: `$error "unsupported type " +++ $Typeof(x)::name;`
//
//  `$echo выражение;` — напечатать значение при КОМПИЛЯЦИИ (в вывод
//  компилятора, а не программы). Это printf-отладка для compile-time
//  кода: `$echo $Typeof(x)::name;` покажет, с каким типом раскрылся
//  макрос.
//
//  ЗАДАЧА:
//    1. Статическая проверка размера `WireHeader` не проходит. В
//       протоколе version и flags — 16-битные беззнаковые числа.
//       Исправьте СТРУКТУРУ (а не проверку!).
//    2. В `area_or_zero` допишите условие: вызывать `x.area()`, только
//       если у значения такой метод есть.
//    3. Раскомментируйте `to_double("oops")` — посмотрите, как работает
//       `$error`, и закомментируйте обратно.
//
import std::io;

struct WireHeader
{
    uint magic;
    ushort version;
    ushort flags;
}

$assert WireHeader::size == 8 : "WireHeader must be exactly 8 bytes";

struct Circle { double r; }
fn double Circle.area(&self) => 3.0 * self.r * self.r;

struct Rect { double w, h; }
fn double Rect.area(&self) => self.w * self.h;

struct Label { String text; }

macro double area_or_zero(x)
{
    $if $defined(x.area()):
        return x.area();
    $else
        return 0.0;
    $endif
}

macro double to_double(x)
{
    $switch:
        $case types::is_int($Typeof(x)):
        $case types::is_float($Typeof(x)):
            return (double)x;
        $case $Typeof(x)::kind == BOOL:
            return x ? 1.0 : 0.0;
        $default:
            $error "to_double: unsupported type " +++ $Typeof(x)::name;
    $endswitch
}

$echo "compiling 083 (this line is printed by the compiler)";

fn void main()
{
    WireHeader h = { 0xC3C3, 1, 0 };
    io::printfn("header: %d bytes, version %d", WireHeader::size, h.version);

    Circle c = { 2.0 };
    Rect r = { 3.0, 4.0 };
    Label l = { "hello" };
    assert(area_or_zero(c) == 12.0);
    assert(area_or_zero(r) == 12.0);
    assert(area_or_zero(l) == 0.0);
    io::printfn("areas: %.1f %.1f %.1f", area_or_zero(c), area_or_zero(r), area_or_zero(l));

    io::printfn("defined: Rect.w=%s Rect.depth=%s Label.area=%s",
                $defined(Rect.w), $defined(Rect.depth), $defined(l.area));
    io::printfn("int from 1.5 allowed: %s", $defined(int v = 1.5));

    io::printfn("to_double: %.1f %.1f %.1f", to_double(3), to_double(2.5f), to_double(true));
    // to_double("oops");
}
