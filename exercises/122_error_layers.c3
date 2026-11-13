// =====================================================================
//  122 · Архитектура обработки ошибок в многослойной системе
// =====================================================================
//
//  В маленькой программе ошибка — это `return SOMETHING~;` и `!`.
//  В большой системе важнее другое: КТО и НА КАКОМ ЯЗЫКЕ о ней узнаёт.
//
//      UI / API          "Недостаточно средств"           код 409
//         ^ перевод
//      сервис (домен)    INSUFFICIENT_FUNDS, ACCOUNT_NOT_FOUND, CORRUPTED
//         ^ перевод
//      хранилище         KEY_MISSING, IO_ERROR
//         ^
//      stdlib/ОС         string::MALFORMED_INTEGER, io::FILE_NOT_FOUND ...
//
//  ПРИНЦИПЫ
//  --------
//  1. Каждый слой говорит на СВОЁМ языке ошибок. Если банковский
//     сервис возвращает наружу `string::MALFORMED_INTEGER`, вызывающий
//     код вынужден знать, что балансы хранятся строками, — утечка
//     абстракции. Сменили хранилище — сломали всех клиентов.
//     Поэтому на границе слоя ошибки ПЕРЕВОДЯТ: KEY_MISSING ->
//     ACCOUNT_NOT_FOUND, IO_ERROR -> STORAGE_UNAVAILABLE, любая ошибка
//     разбора -> CORRUPTED.
//  2. Переводить не всё подряд: «неизвестная» ошибка нижнего слоя не
//     должна молча превращаться в «всё хорошо» или в первую попавшуюся
//     доменную. Явный switch с default — страховка.
//  3. Ошибка в C3 — это просто значение (fault), без полезной нагрузки.
//     Контекст (какой счёт, что именно не распарсилось) кладут рядом:
//     в «последнюю ошибку» контекста/потока (как errno + strerror,
//     или GetLastError), в лог, или возвращают через out-параметр.
//     Мы ведём ErrorContext: код + текст деталей.
//  4. Ошибки — часть контракта функции: в документации указывают
//     `@return? ACCOUNT_NOT_FOUND, INSUFFICIENT_FUNDS`.
//  5. Восстановление и откат — там, где есть знание: транзакция
//     перевода денег знает, что первую запись нужно отменить, если
//     вторая не удалась. В C3 для этого есть `defer catch { ... }` —
//     выполняется ТОЛЬКО при выходе с ошибкой (а `defer try` — только
//     при успехе). Объявлять его надо СРАЗУ после действия, которое
//     откатывает.
//  6. Верхний слой (API/UI) превращает доменные ошибки в коды статуса и
//     сообщения для людей. Только здесь и уместен `!!`/падение —
//     и то лишь в тестах.
//
//  ИНСТРУМЕНТЫ C3
//  --------------
//      if (catch err = foo()) { switch (err) { case KEY_MISSING: ... } }
//      int v = foo() ?? 0;                 // значение по умолчанию
//      int v = foo() ?? OTHER_ERROR~;      // замена ошибки (перевод в одну строку!)
//      foo()!;                             // проброс как есть
//      defer (catch err) { ...откат... }   // только при выходе с ошибкой
//      fault f = @catch(foo());            // достать ошибку (или пустой fault)
//
//  ЗАДАЧА: реализуйте
//    * Bank.balance — чтение и перевод ошибок хранилища/разбора;
//    * Bank.transfer — проверки, две записи и откат первой, если
//      вторая не удалась;
//    * http_status — отображение доменных ошибок в коды.
//
import std::io;
import std::collections::map;

// ================================================================ хранилище

excuse KEY_MISSING, IO_ERROR;

struct Storage
{
    HashMap{String, String} data;
    int writes_until_failure;     // < 0 — никогда; 0 — следующая запись упадёт
    int write_count;
}

fn void Storage.init(&self)
{
    self.data.init(mem);
    self.writes_until_failure = -1;
}

fn void Storage.free(&self) => self.data.free();

fn String? Storage.get(&self, String key) => self.data.get(key) ?? KEY_MISSING~;

fn void? Storage.put(&self, String key, String value)
{
    if (self.writes_until_failure == 0) return IO_ERROR~;
    if (self.writes_until_failure > 0) self.writes_until_failure--;
    self.write_count++;
    self.data.set(key, value);
}

// ================================================================ домен

excuse ACCOUNT_NOT_FOUND, INSUFFICIENT_FUNDS, INVALID_AMOUNT, CORRUPTED, STORAGE_UNAVAILABLE, SAME_ACCOUNT;

struct ErrorContext
{
    fault code;
    DString detail;
}

struct Bank
{
    Storage* store;
    ErrorContext* ctx;
}

// Запомнить контекст и вернуть ошибку (удобно: `return b.fail(X, "...", ...)~;`)
macro fault Bank.fail(&self, fault code, String fmt, ...)
{
    self.ctx.code = code;
    self.ctx.detail.clear();
    self.ctx.detail.appendf(fmt, ...$vaarg);
    return code;
}

<*
 @return? ACCOUNT_NOT_FOUND, CORRUPTED, STORAGE_UNAVAILABLE
*>
fn int? Bank.balance(&self, String account)
{
    // TODO:
    //  * store.get(account): KEY_MISSING -> ACCOUNT_NOT_FOUND,
    //    IO_ERROR -> STORAGE_UNAVAILABLE (через self.fail с деталями
    //    "no account 'X'" / "storage read failed");
    //  * text.to_int(): любая ошибка разбора -> CORRUPTED,
    //    детали "bad balance 'TEXT' for X".
    //  Другие (неожиданные) ошибки — пробросить как есть.
    return 0;
}

fn void? Bank.write_balance(&self, String account, int value)
{
    String text = string::format(mem, "%d", value);   // строки в хранилище живут вечно (для простоты)
    if (catch self.store.put(account, text))
    {
        free(text);
        return self.fail(STORAGE_UNAVAILABLE, "storage write failed for %s", account)~;
    }
}

<*
 @return? INVALID_AMOUNT, SAME_ACCOUNT, ACCOUNT_NOT_FOUND, INSUFFICIENT_FUNDS, CORRUPTED, STORAGE_UNAVAILABLE
*>
fn void? Bank.transfer(&self, String from, String to, int amount)
{
    // TODO:
    //  * amount <= 0 -> INVALID_AMOUNT ("amount must be positive, got N");
    //    from == to -> SAME_ACCOUNT ("cannot transfer to itself");
    //  * прочитать оба баланса (ошибки уже переведены — просто `!`);
    //  * не хватает -> INSUFFICIENT_FUNDS ("FROM has A, needs B");
    //  * записать from - amount; СРАЗУ объявить defer catch, который
    //    вернёт старый баланс from (ошибку самого отката игнорируем: (void));
    //  * записать to + amount.
}

// ================================================================ API-слой

fn int http_status(fault f)
{
    // TODO: нет ошибки (f == {}) -> 200; INVALID_AMOUNT, SAME_ACCOUNT -> 400;
    //       ACCOUNT_NOT_FOUND -> 404; INSUFFICIENT_FUNDS -> 409;
    //       STORAGE_UNAVAILABLE -> 503; всё остальное (в т.ч. CORRUPTED) -> 500.
    return 0;
}

fn int api_transfer(Bank* bank, String from, String to, int amount)
{
    fault f = @catch(bank.transfer(from, to, amount));
    int status = http_status(f);
    if (f)
    {
        io::printfn("POST /transfer %s->%s %d => %d (%s: %s)", from, to, amount, status, f, bank.ctx.detail.str_view());
    }
    else
    {
        io::printfn("POST /transfer %s->%s %d => %d", from, to, amount, status);
    }
    return status;
}

// ================================================================ проверка

fn void main()
{
    Storage store;
    store.init();
    defer store.free();
    ErrorContext ctx = { .detail = dstring::new(mem) };
    defer ctx.detail.free();
    Bank bank = { &store, &ctx };

    store.put("alice", "100")!!;
    store.put("bob", "20")!!;
    store.put("carol", "12abc")!!;     // испорченная запись

    // нижний уровень
    assert(bank.balance("alice")!! == 100);
    assert(@catch(bank.balance("dave")) == ACCOUNT_NOT_FOUND, "KEY_MISSING must become ACCOUNT_NOT_FOUND");
    assert(ctx.detail.str_view() == "no account 'dave'");
    assert(@catch(bank.balance("carol")) == CORRUPTED, "parse error must become CORRUPTED");
    int fallback = bank.balance("dave") ?? -1;
    assert(fallback == -1);

    assert(api_transfer(&bank, "alice", "bob", 30) == 200);
    assert(api_transfer(&bank, "alice", "bob", 0) == 400);
    assert(api_transfer(&bank, "bob", "bob", 5) == 400);
    assert(api_transfer(&bank, "alice", "dave", 5) == 404);
    assert(api_transfer(&bank, "bob", "alice", 500) == 409);
    assert(api_transfer(&bank, "carol", "bob", 1) == 500);

    // сбой посреди транзакции: первая запись проходит, вторая падает
    store.writes_until_failure = 1;
    assert(api_transfer(&bank, "alice", "bob", 10) == 503);
    assert(bank.balance("alice")!! == 70, "first write must be rolled back");
    assert(bank.balance("bob")!! == 50);
    store.writes_until_failure = 0;
    assert(api_transfer(&bank, "alice", "bob", 10) == 503);
    store.writes_until_failure = -1;

    assert(api_transfer(&bank, "alice", "bob", 70) == 200);
    io::printfn("final: alice=%d bob=%d, writes=%d", bank.balance("alice")!!, bank.balance("bob")!!, store.write_count);
    assert(http_status({}) == 200);
}
