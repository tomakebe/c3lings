// =====================================================================
//  074 · Контракты на generic-параметры
// =====================================================================
//
//  Generic-код проверяется при инстанцировании. Если подставить
//  неподходящий тип, ошибка всплывёт где-то в глубине реализации:
//  «'String' can only be compared using '==' ...» в строке 3 модуля,
//  о котором пользователь и не подозревал. В C++ это печально знаменитые
//  ошибки шаблонов на сотни строк; C++20 ответил на это концептами
//  (`template <std::integral T>`), Rust — трейт-ограничениями (`T: Ord`).
//
//  В C3 для этого используются уже знакомые контракты `@require` (см.
//  упражнение 042), но теперь условия проверяются во время КОМПИЛЯЦИИ
//  и могут говорить о параметрах-типах:
//
//      <*
//       @require types::is_int(Type) : "gcd works only for integers"
//      *>
//      fn Type gcd(Type a, Type b) <Type> { ... }
//
//      gcd{double}(1.0, 2.0);
//      // error: @require "types::is_int(Type)" violated:
//      //        'gcd works only for integers'
//
//  Ошибка теперь указывает на место ВЫЗОВА и говорит понятным языком.
//
//  Контракт можно повесить на generic-модуль целиком — тогда он
//  проверяется для любой сущности этого модуля:
//
//      <* @require types::is_numerical(Type) : "Type must be a number" *>
//      module stats <Type>;
//
//  ...или на generic-структуру:
//
//      <* @require Elem::size <= 4 *>
//      struct Small <Elem> { Elem v; }
//
//  Что можно спрашивать о типе:
//    * `Type::kind == TypeKind.SIGNED_INT` — вид типа (SIGNED_INT,
//      UNSIGNED_INT, FLOAT, BOOL, STRUCT, ENUM, POINTER, ...);
//    * `Type::size`, `Type::alignment`, `Type::is_ordered` (можно ли `<`),
//      `Type::has_equals` (можно ли `==`);
//    * готовые макросы из std::core::types: `types::is_int(Type)`
//      (любое целое), `types::is_signed(Type)`, `types::is_unsigned(Type)`,
//      `types::is_float(Type)`, `types::is_numerical(Type)` (целое или
//      float, в т.ч. вектор), `types::is_same(TypeA, TypeB)`;
//    * `$defined(Type x = 1)` — можно ли инициализировать Type единицей
//      (в старых версиях для этого был `$assignable`, в 0.8.5 его нет).
//
//  Операторы `&&&` и `|||` — «ленивые» compile-time версии `&&` и `||`:
//  правая часть даже не проверяется, если левая уже всё решила. Удобно,
//  когда правая часть имеет смысл только при выполнении левой.
//
//  Нюансы:
//    * контракт функции проверяется только при её инстанцировании, а
//      контракт модуля/структуры — при любом использовании группы;
//    * контракты на generic-параметры — это НЕ перегрузка: нарушенный
//      контракт — всегда ошибка компиляции, «выбрать другую версию»
//      компилятор не пытается (и `$defined(f{double})` тоже не спасёт —
//      это будет ошибка, а не false);
//    * хороший контракт — минимальный: требуйте ровно то, что реально
//      нужно реализации. Слишком строгий контракт запрещает разумные
//      применения, и это тоже баг.
//
//  ЗАДАЧА:
//    1. Допишите контракт модуля `stats`: Type должен быть числом.
//    2. Контракт `gcd` слишком строгий — из-за него не компилируется
//       совершенно разумный `gcd{uint}`. Исправьте его: gcd имеет смысл
//       для ЛЮБЫХ целых (знаковых и беззнаковых).
//    3. Для интереса раскомментируйте строки «ошибка» в main и посмотрите
//       на сообщения компилятора (потом закомментируйте обратно).
//
<*
 @require types::is_numerical(Type) : "stats: Type must be a number"
*>
module stats <Type>;

fn Type sum(Type[] xs)
{
    Type s;
    foreach (x : xs) s += x;
    return s;
}

fn double mean(Type[] xs) => (double)sum(xs) / xs.len;

module app;
import std::io;
import stats;

<*
 @require types::is_int(Type) : "gcd works only for integers"
*>
fn Type gcd(Type a, Type b) <Type>
{
    while (b != 0)
    {
        Type t = a % b;
        a = b;
        b = t;
    }
    return a;
}

<*
 @require types::is_int(Elem) &&& Elem::size <= 2 : "Small: only 8/16-bit integers"
*>
struct Small <Elem>
{
    Elem v;
}

fn void main()
{
    float[] temps = { 20.5, 22.0, 18.0, 23.5 };
    io::printfn("mean temp: %.2f", stats::mean{float}(temps));

    uint[] counts = { 3, 4, 5 };
    io::printfn("total count: %d", stats::sum{uint}(counts));

    uint g = gcd{uint}(84, 36);
    assert(g == 12);
    io::printfn("gcd(84, 36) = %d", g);
    io::printfn("gcd(-12, 18) = %d", gcd{long}(-12, 18));

    Small{short} s = { 300 };
    io::printfn("small: %d, %d bytes", s.v, Small{short}::size);

    // ошибка: String — не число
    // String[] words = { "a", "b" };
    // stats::sum{String}(words);

    // ошибка: gcd для float не определён
    // gcd{double}(1.0, 2.0);

    // ошибка: int — 4 байта
    // Small{int} big;
}
