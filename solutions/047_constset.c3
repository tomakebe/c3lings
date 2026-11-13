// =====================================================================
//  047 · `constset` — набор именованных констант
// =====================================================================
//
//  Вспомним 026: `enum` в C3 — это всегда значения 0, 1, 2, ... без
//  пропусков. Зато у enum'а есть имена (`.nameof`), `values`,
//  `from_ordinal` и switch проверяет, что все варианты разобраны.
//  Задать enum'у произвольное число, как в C (`OK = 200`), НЕЛЬЗЯ.
//
//  А что, если значения заданы извне — коды HTTP, коды клавиш из
//  C-библиотеки, битовые флаги? Для этого `constset`:
//
//      constset HttpStatus : int     // базовый тип
//      {
//          OK = 200,
//          CREATED,                  // нет значения => предыдущее + 1 = 201
//          NOT_FOUND = 404,
//      }
//
//  Свойства constset'а:
//  * Это отдельный тип (как typedef, см. 040): `HttpStatus s = 404;` —
//    ошибка, нужно `(HttpStatus)404`. Обратно — тоже явно: `(int)s`.
//  * Он НЕ проверяет, что значение — одно из объявленных: в переменной
//    может оказаться `(HttpStatus)500`, которого в списке нет. Поэтому в
//    switch по constset'у обычно нужен `default`.
//  * Доступ к константе: `HttpStatus.OK`, а там, где тип понятен из
//    контекста (присваивание, case, аргумент), — просто `OK`.
//  * Печать `%s` / `%d` выводит ЧИСЛО (имён у constset'а во время
//    выполнения нет — в отличие от enum).
//  * С флагами работают битовые операции: `Perm.READ | Perm.WRITE`,
//    а `if (p & Perm.WRITE)` проверяет бит.
//  * Базовый тип может быть любым, даже `String`. С `inline`
//    (`constset Color : inline String { ... }`) константа неявно
//    превращается в базовый тип.
//
//  Правило выбора: нужен закрытый список вариантов — `enum`; нужны
//  конкретные числа, совместимые с внешним миром, — `constset`.
//
//  ЗАДАЧА: почините четыре места, помеченные `// <-`.
//
import std::io;

constset HttpStatus : int // <- у enum не может быть значений вроде 200
{
    OK = 200,
    CREATED,
    NO_CONTENT = 204,
    NOT_FOUND = 404,
    TEAPOT = 418,
}

constset Perm : uint
{
    EXEC = 1,
    WRITE = 2,
    READ = 4,
}

fn String describe(HttpStatus s)
{
    switch (s)
    {
        case OK:
        case CREATED:
        case NO_CONTENT: return "success";
        case NOT_FOUND: return "not found";
        case TEAPOT: return "i am a teapot";
        default: return "unknown";
    }
}

fn void main()
{
    assert((int)HttpStatus.CREATED == 201); // <- какое значение у CREATED?

    int[4] from_server = { 204, 418, 500, 404 };
    foreach (code : from_server)
    {
        HttpStatus s = (HttpStatus)code; // <- int -> HttpStatus только явно
        io::printfn("%d: %s", s, describe(s));
    }

    Perm mine = Perm.READ | Perm.WRITE;
    uint mode = (uint)mine; // <- Perm -> uint только явно
    io::printfn("mode = %d", mode);
    if (mine & Perm.WRITE) io::printn("can write");
    if (!(mine & Perm.EXEC)) io::printn("cannot execute");
    assert(mode == 6);
}
