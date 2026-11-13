// =====================================================================
//  073 · Generic-модули и группировка generics
// =====================================================================
//
//  Если в модуле много обобщённого кода с одними и теми же параметрами,
//  удобно сделать generic САМ МОДУЛЬ (точнее, секцию модуля):
//
//      module numeric <Type>;
//
//      fn Type max(Type a, Type b) => a > b ? a : b;
//      fn Type min(Type a, Type b) => a < b ? a : b;
//      fn Type clamp(Type x, Type lo, Type hi) => max(lo, min(x, hi));
//
//  Каждое объявление в такой секции получает параметр `<Type>`
//  автоматически — писать `<Type>` после каждой функции не нужно.
//  Внутри секции функции зовут друг друга без `{...}`: `max(lo, ...)`
//  внутри `clamp{int}` — это `max{int}`.
//
//  Снаружи всё как обычно:
//
//      import numeric;
//      numeric::clamp{double}(1.5, 0.0, 1.0);
//      alias clamp_int = numeric::clamp{int};
//
//  Это прямой наследник старого стиля C3 (`module list <Type>;` в
//  стандартной библиотеке — посмотрите `lib/std/collections/`). В C
//  ближайший аналог — «шаблонный» заголовочный файл, который включают
//  несколько раз с разными `#define T int`. В C3 то же самое, но
//  с проверкой типов, без препроцессора и с нормальными сообщениями.
//
//  Один файл может содержать несколько секций модулей (`module a;`,
//  `module a <Type>;`, `module app;`) — так и сделано в этом упражнении.
//
//  ГРУППИРОВКА. Важная и неочевидная особенность: generics внутри одного
//  модуля, у которых ОДИНАКОВЫЕ имена параметров, образуют одну группу и
//  инстанцируются ВМЕСТЕ. Неважно, объявлены они в generic-секции или
//  по отдельности:
//
//      module numeric <Type>;
//      fn Type max(Type a, Type b) => ...;        // группа <Type>
//
//      module numeric;
//      struct Tagged <Type> { ... }               // ТА ЖЕ группа <Type>!
//      fn Elem first(Elem[] xs) <Elem> => ...;    // другая группа <Elem>
//
//  Написав `Tagged{String}`, вы заставите компилятор создать и
//  `max{String}`, и `min{String}`, и `clamp{String}` — а строки нельзя
//  сравнивать через `>`. Ошибка при этом укажет на `max`, хотя вы его
//  вообще не вызывали! Это похоже на то, как в C++ инстанцируется весь
//  шаблон класса, но там методы хотя бы ленивые.
//
//  Зачем так сделано? Группа — это «пакет» связанных объявлений: тип и
//  функции для работы с ним всегда существуют вместе и видят друг друга.
//  Отсюда практическое правило: несвязанные generics, которые могут
//  инстанцироваться разными типами, либо держите в разных модулях,
//  либо давайте их параметрам РАЗНЫЕ имена.
//
//  ЗАДАЧА:
//    1. Объявите `alias clamp_int` — версию `numeric::clamp` для int.
//    2. Программа не компилируется из-за `Tagged{String}`. Прочитайте
//       ошибку, поймите, почему виноват `max`, и почините, НЕ трогая
//       модуль `app` и generic-секцию `numeric <Type>`.
//
module numeric <Type>;

fn Type max(Type a, Type b) => a > b ? a : b;
fn Type min(Type a, Type b) => a < b ? a : b;
fn Type clamp(Type x, Type lo, Type hi) => max(lo, min(x, hi));

module numeric;

// Значение с подписью. Ему не нужно уметь сравнивать значения.
struct Tagged <Value>
{
    String tag;
    Value value;
}

module app;
import std::io;
import numeric;

alias clamp_int = numeric::clamp{int};

fn void main()
{
    int a = clamp_int(15, 0, 10);
    int b = clamp_int(-3, 0, 10);
    assert(a == 10 && b == 0);
    io::printfn("clamp_int: %d %d", a, b);

    double d = numeric::clamp{double}(0.25, 0.0, 1.0);
    io::printfn("clamp double: %.2f", d);

    Tagged{String} greeting = { "greeting", "hello" };
    Tagged{int} answer = { "answer", 42 };
    io::printfn("%s = %s", greeting.tag, greeting.value);
    io::printfn("%s = %d", answer.tag, answer.value);
}
