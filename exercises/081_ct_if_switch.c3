// =====================================================================
//  081 · `$if` и `$switch`
// =====================================================================
//
//  Макрос с нетипизированным параметром принимает что угодно. Но что,
//  если для строки нужно сделать одно, а для числа — другое? Обычный
//  `if` тут не поможет:
//
//      macro weight(x)
//      {
//          if ($Typeof(x)::typeid == String::typeid) return x.len;
//          return x;
//      }
//      weight(5);   // ОШИБКА: There is no member or method 'len' on 'int'
//
//  Условие-то вычисляется при компиляции, но обычный `if` — конструкция
//  времени выполнения: ОБЕ ветки должны компилироваться для любого типа.
//
//  Для этого есть compile-time условия:
//
//      $if <константное условие>:
//          ...
//      $else
//          ...
//      $endif
//
//  Обратите внимание на синтаксис: двоеточие после условия, никаких
//  фигурных скобок, `$endif` в конце. Ветка, которая не выбрана,
//  ВЫБРАСЫВАЕТСЯ и даже не проверяется на типы — как `#if` в C или
//  `if constexpr` в C++17, или `if` над comptime-значением в Zig. Но, в
//  отличие от `#if`, это не текстовый препроцессор: код внутри должен
//  быть синтаксически правильным, а условие — нормальным выражением C3
//  (типы, `::size`, макросы, `$defined`...).
//
//  Для нескольких вариантов — `$switch`:
//
//      $switch $Typeof(x)::kind:
//          $case SIGNED_INT:
//          $case UNSIGNED_INT:          // пустой case проваливается дальше
//              return "integer";
//          $case FLOAT:
//              return "float";
//          $default:
//              return "other";
//      $endswitch
//
//  Переключаться можно и по самим типам: `$switch $Typeof(x): $case int:
//  ... $case String: ...`. А `$switch` без выражения работает как цепочка
//  `$if`/`$else`: в каждом `$case` — своё условие.
//
//  Где можно использовать: внутри функций и макросов. На верхнем уровне
//  файла (вокруг объявлений) `$if` запрещён — там для условной
//  компиляции служат атрибуты `@feat`/`@if` (упражнение 091). Это
//  принципиальная позиция C3: объявления не должны «возникать из
//  ниоткуда», как в C с `#ifdef`, — их всегда видно в исходнике.
//
//  Типичные применения: разное поведение для разных видов типов в
//  макросах и generic-коде, платформозависимый код, отладочные ветки.
//
//  ЗАДАЧА:
//    1. Почините `weight`: используйте `$if`/`$switch` вместо обычного
//       `if`, чтобы каждая ветка компилировалась только для своего типа.
//       Правила: String -> длина, bool -> 1 или 0, float/double -> значение,
//       округлённое вниз (приведение к long), целое -> само значение.
//       Результат всегда long.
//    2. Допишите `$case` в `describe`, чтобы вывод совпал с ожидаемым.
//
import std::io;

macro long weight(x)
{
    // Не компилируется: обычный if проверяет ОБЕ ветки для любого типа.
    if ($Typeof(x)::typeid == String::typeid) return x.len;
    if ($Typeof(x)::kind == BOOL) return x ? 1 : 0;
    if (types::is_float($Typeof(x))) return (long)x;
    return x;
}

macro void describe(x)
{
    $switch $Typeof(x):
        $case int:
            io::printfn("int %d", x);
        // TODO: строки печатаются как: string "hi" of length 2
        $case double:
            io::printfn("double %.2f", x);
        $default:
            io::printfn("something of type %s", $Typeof(x)::name);
    $endswitch
}

fn void main()
{
    assert(weight("hello") == 5);
    assert(weight(true) == 1);
    assert(weight(false) == 0);
    assert(weight(3.9) == 3);
    assert(weight(42) == 42);
    assert(weight((ushort)7) == 7);
    io::printfn("total weight: %d",
                weight("hello") + weight(true) + weight(3.9) + weight(42));

    describe(42);
    describe("hi");
    describe(1.5);
    describe('c');

    $if int::size == 4:
        io::printn("int is 32-bit");
    $else
        io::printn("int is unusual");
    $endif
}
