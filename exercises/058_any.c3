// =====================================================================
//  058 · any и typeid: значения неизвестного типа
// =====================================================================
//
//  Иногда функция должна принимать «что угодно»: логгер, сериализатор,
//  тот же printf. В C для этого есть `void*` — и полная потеря
//  информации о типе. В C3 есть `any`: это пара
//      { void* ptr;  typeid type; }
//  то есть указатель ПЛЮС описание типа того, на что он указывает.
//
//  Создаётся `any` из УКАЗАТЕЛЯ (не из значения!):
//      int x = 5;
//      any a = &x;          // a.ptr == &x, a.type == int::typeid
//      any b = &&2.5;       // && — адрес временного значения
//
//  `typeid` — значение-«ярлык» типа во время выполнения. Получить его
//  можно как `Foo::typeid`. В рантайме у typeid доступны `.size`,
//  `.kind` (INT, STRUCT, POINTER... — enum TypeKind), а вот `.name`
//  только во время компиляции.
//
//  Проверка и извлечение значения:
//
//      switch (a.type)
//      {
//          case int:                       // ::typeid можно не писать
//              int v = *(int*)a;           // после проверки — безопасно
//          case double:
//              ...
//          default:
//              ...
//      }
//
//  Каст `(int*)a` достаёт указатель, и его надо разыменовать. Каст НЕ
//  проверяет тип: `(double*)a` на int'е — это чтение мусора. Поэтому
//  либо проверяйте `.type` (switch, if), либо используйте `anycast`:
//      if (try p = anycast(a, int)) io::printn(*p);  // int*? — Optional
//
//  Важно: типы сравниваются ТОЧНО. `case int:` не поймает `long` или
//  `char`, а `String` и `char[]` — разные typeid.
//
//  `any` связан с вариадиками из 049: в `fn void f(args...)` каждый
//  аргумент неявно превращается в `any` (берётся его адрес). Именно так
//  устроены `io::printfn` и `string::tformat`.
//
//  ЗАДАЧА: допишите `describe`, чтобы он узнавал String, правильно
//  извлекал int и подсчитайте в `sum_numbers` только целые.
//  Ожидаемый вывод:
//      int 42
//      double 2.50
//      String "hello"
//      Point(1, 2)
//      unknown BOOL
//      unknown SIGNED_INT
//      sum = 10
//
import std::io;

struct Point
{
    int x, y;
}

fn String describe(any value)
{
    switch (value.type)
    {
        case int:
            return string::tformat("int %d", (int)value);   // <- any это не int
        case double:
            return string::tformat("double %.2f", *(double*)value);
        // TODO: case для String -> String "..."
        case Point:
            Point* p = (Point*)value;
            return string::tformat("Point(%d, %d)", p.x, p.y);
        default:
            return string::tformat("unknown %s", value.type.kind);
    }
}

// Складывает только аргументы типа int, остальное пропускает.
fn int sum_numbers(args...)
{
    int total;
    foreach (arg : args)
    {
        total += *(int*)arg;   // <- а если это не int?
    }
    return total;
}

fn void main()
{
    int answer = 42;
    String greeting = "hello";
    Point pt = { 1, 2 };
    bool flag = true;
    long big = 7;

    any[] things = { &answer, &&2.5, &greeting, &pt, &flag, &big };
    foreach (thing : things) io::printn(describe(thing));

    io::printfn("sum = %d", sum_numbers(1, "two", 3, 4.0, 6));
}
