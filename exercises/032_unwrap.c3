// =====================================================================
//  032 · Распаковка Optional: `if (catch ...)`, `if (try ...)`
// =====================================================================
//
//  В прошлом упражнении мы только «подглядывали» в Optional через
//  @ok/@catch. Но чтобы ДОСТАТЬ значение, нужна распаковка.
//
//  1) `if (catch err = opt) { ... }`
//
//     Если Optional пуст, его ошибка (типа `fault`) кладётся в `err`,
//     и выполняется тело. Имя можно опустить: `if (catch opt) ...`.
//     Ошибку удобно разбирать через `switch` — case'ы по значениям fault:
//
//         if (catch err = value)
//         {
//             switch (err)
//             {
//                 case NOT_FOUND: ...
//                 case io::EOF:   ...    // ошибки из других модулей — с префиксом
//                 default:        ...
//             }
//         }
//
//  2) Flow typing (вывод типа по потоку управления) — главная фишка.
//     Если тело `if (catch ...)` гарантированно ВЫХОДИТ из текущей
//     области (`return`, `break`, `continue`, ...), то после этого `if`
//     компилятор ЗНАЕТ, что ошибки нет, и переменная становится обычным
//     `int` вместо `int?`:
//
//         int? v = s.to_int();
//         if (catch err = v) return err~;  // пробросить ошибку дальше
//         // здесь v — уже просто int!
//         return v * 2;
//
//     Если же из блока catch можно «провалиться» вниз — `v` остаётся
//     `int?`, и с ним нельзя работать как с числом.
//
//     Обратите внимание на `return err~;` — пойманную ошибку можно
//     вернуть дальше тем же суффиксом `~`.
//
//  3) `if (try v = opt) { ... }` — обратная форма: тело выполняется
//     только если результат ЕСТЬ, и внутри `v` — обычное значение.
//     Если Optional — уже переменная, можно без нового имени:
//     `if (try opt) { /* тут opt — обычный int */ }`.
//     Несколько условий соединяются только через `&&`:
//
//         if (try a = f() && try b = g()) { ... a + b ... }
//
//  Стандартная библиотека тоже возвращает Optional: `String.to_int()`
//  возвращает `int?` с ошибками вроде `string::MALFORMED_INTEGER`.
//
//  ЗАДАЧА: почините три места, помеченные `// <-`.
//
import std::io;

excuse EMPTY_INPUT, OUT_OF_RANGE;

fn int? parse_score(String s)
{
    if (s.len == 0) return EMPTY_INPUT~;
    int? v = s.to_int();
    if (catch err = v)
    {
        io::printfn("  cannot parse '%s'", s);
        // <- блок catch должен выйти из функции
    }
    // Благодаря flow typing здесь v — обычный int.
    if (v < 0 || v > 100) return OUT_OF_RANGE~;
    return v;
}

fn void main()
{
    String[] inputs = { "90", "", "abc", "75", "250", "-1", "35" };
    int total;
    int empty;
    int malformed;
    int out_of_range;

    foreach (s : inputs)
    {
        int? score = parse_score(s);
        if (catch err = score)
        {
            switch (err)
            {
                case EMPTY_INPUT: empty++;
                case ???: malformed++; // <- какая ошибка у "abc"?
                case OUT_OF_RANGE: out_of_range++;
                default: unreachable("unexpected fault");
            }
            continue;
        }
        total += score;
    }

    io::printfn("total=%d empty=%d malformed=%d out_of_range=%d",
                total, empty, malformed, out_of_range);
    assert(total == 200 && empty == 1 && malformed == 1 && out_of_range == 2);

    if (??? best = parse_score("100")) // <- выполнить, только если результат есть
    {
        io::printfn("best=%d", best);
    }
    if (try a = parse_score("40") && try b = parse_score("2"))
    {
        io::printfn("a+b=%d", a + b);
    }
}
