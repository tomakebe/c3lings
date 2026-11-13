// =====================================================================
//  104 · Optional в сложных сценариях
// =====================================================================
//
//  Основы Optional вы знаете: `int?` — это «int или ошибка (excuse)»,
//  `return ERR~` возвращает ошибку, `!` пробрасывает её выше, `!!`
//  паникует, `if (catch err = x)` и `if (try v = x)` разбирают
//  результат. Теперь соберём весь инструментарий вместе — так, как он
//  используется в настоящем коде.
//
//  1. Optional «заражает» выражения
//  --------------------------------
//      int? a = get();
//      int? b = a * 2 + 1;      // если a — ошибка, b — та же ошибка
//      int? r = twice(a);       // если a — ошибка, twice даже НЕ вызывается
//
//  Ошибка тихо «протекает» по выражению, как NaN по формуле, пока её
//  кто-нибудь не обработает. Вызов функции с пустым Optional-аргументом
//  пропускается целиком (вместе с побочными эффектами!).
//
//  2. Значение по умолчанию: `??`
//  ------------------------------
//      int workers = get_int(cfg, "workers") ?? 4;
//      int? port = parse(s) ?? INVALID_PORT~;   // заменить одну ошибку другой
//
//  Справа может быть и другая ошибка — так переводят ошибки нижнего
//  уровня (BAD_NUMBER) в термины своего уровня (INVALID_PORT).
//
//  3. Проброс: `!`
//  ---------------
//      fn int? get_int(String[] cfg, String key)
//      {
//          return parse_int(find_value(cfg, key)!)!;
//      }
//
//  `expr!` — «если ошибка — немедленно return её из ЭТОЙ функции».
//  Аналог `?` в Rust и `try` в Zig. (Последний `!` здесь можно
//  опустить: возвращаемое значение уже Optional того же типа.)
//
//  4. Несколько значений сразу
//  ---------------------------
//      if (try w = width(), try h = height())   // ОШИБКА: так нельзя
//      if (try w = width() && try h = height())  // так можно: оба есть
//      {
//          area = w * h;    // здесь w и h — обычные int
//      }
//
//  5. Достать ошибку как значение
//  ------------------------------
//      fault f = @catch(load(cfg));   // пустой fault (null), если ошибки не было
//      bool ok = @ok(load(cfg));
//      if (f == MISSING_KEY) ...
//      if (catch err = load(cfg))
//      {
//          switch (err)
//          {
//              case MISSING_KEY: ...
//              case BAD_NUMBER: ...
//              default: ...
//          }
//      }
//
//  6. Уборка при ошибке: `defer catch`
//  -----------------------------------
//      defer catch io::printn("rollback");              // только при ошибке
//      defer (catch err) io::printfn("failed: %s", err); // ...и с самой ошибкой
//      defer try io::printn("committed");               // только при успехе
//
//  Это заменяет пресловутое `goto cleanup;` из C: ресурсы, выделенные
//  для результата, освобождаются, только если результат не отдаётся
//  вызывающему.
//
//  Чем это лучше исключений C++: путь ошибки виден в типе (`int?`) и
//  в коде (`!`), ничего не «пролетает» незаметно, нет стоимости
//  раскрутки стека. Чем лучше кодов возврата C: нельзя случайно
//  забыть проверить — компилятор не даст использовать `int?` как `int`.
//
//  ЗАДАЧА: допишите загрузчик конфигурации (места помечены TODO):
//    1. get_int — найти значение и разобрать число, пробрасывая ошибки;
//    2. в load: port обязателен, workers по умолчанию 4, ошибки
//       разбора timeout заменить на INVALID_TIMEOUT;
//    3. в describe — превратите ошибку в человекочитаемое сообщение.
//
//  Ожидаемый вывод:
//      config 0: port=8080 workers=8 timeout=30
//      config 1: port=80 workers=4 timeout=5
//        (load failed: optcfg::MISSING_KEY)
//      config 2: error: required key is missing
//        (load failed: optcfg::BAD_NUMBER)
//      config 3: error: not a number
//        (load failed: optcfg::INVALID_TIMEOUT)
//      config 4: error: timeout must be 1..300
//      total capacity: 244
//        (load failed: optcfg::MISSING_KEY)
//
//  (последняя строка — от assert'а с @catch в конце main: load всё же
//  вызывается, и его defer срабатывает.)
//
module optcfg;
import std::io;

excuse MISSING_KEY, BAD_NUMBER, INVALID_TIMEOUT;

struct Config
{
    int port;
    int workers;
    int timeout;
}

fn String? find_value(String[] lines, String key)
{
    foreach (line : lines)
    {
        sz? eq = line.index_of_char('=');
        if (catch eq) continue;
        if (line[:eq] == key) return line[eq + 1..];
    }
    return MISSING_KEY~;
}

fn int? parse_int(String s)
{
    if (s.len == 0) return BAD_NUMBER~;
    int result = 0;
    foreach (c : s)
    {
        if (c < '0' || c > '9') return BAD_NUMBER~;
        result = result * 10 + (c - '0');
    }
    return result;
}

fn int? get_int(String[] cfg, String key)
{
    // TODO: одна строка: find_value + parse_int с пробросом ошибок
    return MISSING_KEY~;
}

fn Config? load(String[] cfg)
{
    defer (catch err) io::printfn("  (load failed: %s)", err);

    Config c;
    c.port = 0;     // TODO: обязательный ключ "port" — ошибка пробрасывается
    c.workers = 0;  // TODO: ключ "workers", по умолчанию 4
    // TODO: ключ "timeout"; ЛЮБАЯ ошибка (нет ключа, не число) -> INVALID_TIMEOUT
    int timeout = 0;
    if (timeout < 1 || timeout > 300) return INVALID_TIMEOUT~;
    c.timeout = timeout;
    return c;
}

fn String describe(fault err)
{
    // TODO: MISSING_KEY -> "required key is missing",
    //       BAD_NUMBER -> "not a number",
    //       INVALID_TIMEOUT -> "timeout must be 1..300",
    //       остальное -> "unknown error"
    return "unknown error";
}

fn void main()
{
    String[][] configs = {
        { "port=8080", "workers=8", "timeout=30" },
        { "timeout=5", "port=80" },
        { "workers=2", "timeout=10" },
        { "port=80x", "timeout=10" },
        { "port=443", "timeout=900" },
    };
    foreach (i, cfg : configs)
    {
        Config? c = load(cfg);
        if (catch err = c)
        {
            io::printfn("config %d: error: %s", i, describe(err));
            continue;
        }
        io::printfn("config %d: port=%d workers=%d timeout=%d", i, c.port, c.workers, c.timeout);
    }

    // Optional «протекает» через выражение: ошибка любого слагаемого
    // делает пустой всю сумму.
    int? total = load(configs[0]).workers * load(configs[0]).timeout
               + load(configs[1]).workers * 1;
    io::printfn("total capacity: %d", total ?? -1);
    assert(@catch(load(configs[2]).workers + 1) == MISSING_KEY);
}
