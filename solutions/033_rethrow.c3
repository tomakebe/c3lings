// =====================================================================
//  033 · Проброс ошибки `!` и принудительная распаковка `!!`
// =====================================================================
//
//  Очень часто функция не знает, что делать с ошибкой, и хочет просто
//  передать её вызывающему. Писать каждый раз
//
//      int? tmp = foo();
//      if (catch err = tmp) return err~;
//
//  утомительно. Для этого есть постфиксный оператор `!` («rethrow»):
//
//      int x = foo()!;
//
//  Если в `foo()` ошибка — текущая функция немедленно возвращает эту
//  же ошибку. Если нет — `x` получает обычное значение (`int`, не
//  `int?`). Это аналог `?` в Rust или `try` в Zig.
//
//  Важно: `!` можно использовать только в функции, которая сама
//  возвращает Optional (`int?`, `void?`, `String?`...). Иначе куда же
//  пробрасывать ошибку? Компилятор это проверит.
//
//  Второй оператор — `!!` («force unwrap»):
//
//      int x = foo()!!;
//
//  Если ошибки нет — получаем значение. Если есть — программа
//  ПАДАЕТ с паникой. Это не обработка ошибок, а утверждение «здесь
//  ошибки быть не может, а если есть — это баг». Уместно в тестах,
//  в прототипах и там, где входные данные заведомо корректны.
//  В отличие от `!`, `!!` можно писать в любой функции.
//
//  Optional-цепочки: `!` можно применять к любому выражению, в том
//  числе прямо к вызову метода: `line[i + 1..].to_int()!`.
//
//  `main` не может возвращать Optional, поэтому ошибки «всплывают»
//  до какого-то уровня, где их обрабатывают (if-catch) или где мы
//  уверены, что их нет (`!!`).
//
//  ЗАДАЧА: почините три места, помеченные `// <-`.
//
import std::io;

excuse WRONG_KEY, NO_EQUALS;

// "width=640" + "width" -> "640"
fn String? value_of(String line, String key)
{
    sz? eq = line.index_of_char('=');
    if (catch eq) return NO_EQUALS~;
    if (line[:eq] != key) return WRONG_KEY~;
    return line[eq + 1..];
}

fn int? int_setting(String line, String key)
{
    String text = value_of(line, key)!;
    return text.to_int();
}

fn int? area(String w_line, String h_line)
{
    int w = int_setting(w_line, "width")!; // <- нужен проброс ошибки
    int h = int_setting(h_line, "height")!;
    return w * h;
}

fn int? perimeter(String w_line, String h_line) // <- функция использует `!`
{
    int w = int_setting(w_line, "width")!;
    int h = int_setting(h_line, "height")!;
    return 2 * (w + h);
}

fn void report(String w_line, String h_line)
{
    int? a = area(w_line, h_line);
    if (catch err = a)
    {
        io::printfn("%s / %s -> error %s", w_line, h_line, err.description);
        return;
    }
    io::printfn("%s / %s -> area %d", w_line, h_line, a);
}

fn void main()
{
    report("width=4", "height=5");
    report("width=4", "heigth=5");
    report("width4", "height=5");
    report("width=x", "height=5");

    // Эти данные заведомо корректны — ошибки быть не может.
    int p = perimeter("width=10", "height=20")!!; // <- достаньте значение «силой»
    io::printfn("perimeter %d", p);
    assert(p == 60);
}
