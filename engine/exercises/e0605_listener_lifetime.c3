// =====================================================================
//  E0605 · Время жизни подписчиков: отписка во время рассылки
// =====================================================================
//
//  Сначала прочитайте engine/docs/06_events.md (раздел 7).
//
//  Самые неприятные баги систем событий — не в доставке, а во ВРЕМЕНИ
//  ЖИЗНИ подписчиков:
//
//    1. Подписчик отписывается (или его уничтожают) ИЗНУТРИ emit().
//       Если список хранится в растущем массиве и мы удалим элемент
//       сдвигом, цикл emit() пропустит следующего подписчика или выйдет
//       за границу.
//    2. Подписчик подписывает нового ИЗНУТРИ emit(). push() может
//       переаллоцировать массив, и указатель/итератор, по которому идёт
//       цикл, повиснет. Даже без реаллокации непонятно: звать новичка
//       в этой же рассылке или нет?
//    3. Обработчик сам вызывает emit() (реентерабельность). Вложенная
//       рассылка не должна «убирать мусор» под ногами внешней.
//    4. Объект уничтожен, а подписку не снял: ctx указывает в
//       освобождённую память — use-after-free при следующем emit().
//
//  Проверенная схема (так устроены, например, делегаты в Unreal и
//  большинство signal-библиотек):
//
//    * пока идёт рассылка (depth > 0), список подписчиков НЕ меняет
//      форму: отписка только ставит флаг `removed`, а новые подписки
//      копятся в отдельном списке `pending`;
//    * когда завершается самая внешняя рассылка (depth вернулся к 0),
//      выполняется finalize(): помеченные удаляются (с сохранением
//      порядка), pending дописываются в конец;
//    * подписка возвращает уникальный id (никогда не переиспользуется,
//      0 — «нет подписки»), поэтому повторная отписка по старому id
//      безопасна и не снимет чужую подписку;
//    * «отписать всё, что принадлежит этому объекту» — unsubscribe_owner
//      (аналог RemoveAll(this) в Unreal) — вызывается из деструктора
//      владельца, это и есть лекарство от пункта 4.
//
//  ЗАДАЧА: реализуйте методы Dispatcher, помеченные TODO.
//
import std::io;
import std::collections::list;

alias Callback = fn void(void* ctx, Dispatcher* d, int value);

struct Listener
{
    uint id;
    Callback cb;
    void* ctx;
    bool removed;
}

struct Dispatcher
{
    List{Listener} live;
    List{Listener} pending;
    uint next_id;
    int depth;
}

fn void Dispatcher.free(&self)
{
    self.live.free();
    self.pending.free();
}

<* Возвращает новый уникальный id (1, 2, 3, ...). Во время рассылки — в pending. *>
fn uint Dispatcher.subscribe(&self, Callback cb, void* ctx)
{
    // TODO
    return 0;
}

<*
 Снимает подписку. Во время рассылки — только помечает removed.
 Подписку из pending можно удалить сразу (по ней ещё не итерируются).
 @return "false, если такой (живой) подписки нет"
*>
fn bool Dispatcher.unsubscribe(&self, uint id)
{
    // TODO
    return false;
}

<* Снимает все подписки с данным ctx. Возвращает их число. *>
fn int Dispatcher.unsubscribe_owner(&self, void* ctx)
{
    // TODO
    return 0;
}

<* Удаляет помеченные (с сохранением порядка) и переносит pending в live. *>
fn void Dispatcher.finalize(&self)
{
    // TODO
}

fn void Dispatcher.emit(&self, int value)
{
    // TODO
}

// ---------------------------------------------------------------------
// Подписчики. Каждый пишет свою букву в общий журнал.
// ---------------------------------------------------------------------

char[128] g_log;
int g_log_len;
fn void note(char c) { if (g_log_len < 128) g_log[g_log_len++] = c; }

struct Actor
{
    char name;
    uint sub;          // id своей подписки
    uint victim;       // кого отписать (для C)
    void* owner_to_kill; // чьи подписки снять (для K)
    int calls;
}

fn void plain(void* ctx, Dispatcher* d, int value)
{
    Actor* a = ctx;
    a.calls++;
    note(a.name);
}

// Одноразовый: отписывает сам себя при первом вызове.
fn void one_shot(void* ctx, Dispatcher* d, int value)
{
    Actor* a = ctx;
    a.calls++;
    note(a.name);
    assert(d.unsubscribe(a.sub));
    assert(!d.unsubscribe(a.sub), "second unsubscribe of the same id must fail");
}

// На value == 2 отписывает ДРУГОГО (стоящего позже в списке).
fn void killer(void* ctx, Dispatcher* d, int value)
{
    Actor* a = ctx;
    a.calls++;
    note(a.name);
    if (value == 2) assert(d.unsubscribe(a.victim));
}

Actor g_newbie = { .name = 'N' };

// На value == 3 подписывает новичка.
fn void recruiter(void* ctx, Dispatcher* d, int value)
{
    Actor* a = ctx;
    a.calls++;
    note(a.name);
    if (value == 3) g_newbie.sub = d.subscribe(&plain, &g_newbie);
}

// На value == 4 делает вложенную рассылку и уничтожает владельца.
fn void reentrant(void* ctx, Dispatcher* d, int value)
{
    Actor* a = ctx;
    a.calls++;
    note(a.name);
    if (value == 4)
    {
        note('(');
        d.emit(40);
        note(')');
        assert(d.unsubscribe_owner(a.owner_to_kill) == 2, "owner had two subscriptions");
    }
}

fn void main()
{
    Dispatcher d;
    defer d.free();

    Actor a = { .name = 'A' };
    Actor b = { .name = 'B' };
    Actor c = { .name = 'C' };
    Actor v = { .name = 'V' };
    Actor r = { .name = 'R' };
    Actor x = { .name = 'X' };
    Actor o = { .name = 'O' };

    a.sub = d.subscribe(&plain, &a);
    b.sub = d.subscribe(&one_shot, &b);
    c.sub = d.subscribe(&killer, &c);
    v.sub = d.subscribe(&plain, &v);
    r.sub = d.subscribe(&recruiter, &r);
    x.sub = d.subscribe(&reentrant, &x);
    o.sub = d.subscribe(&plain, &o);
    d.subscribe(&plain, &o);           // у O две подписки
    c.victim = v.sub;
    x.owner_to_kill = &o;
    assert(a.sub == 1 && o.sub == 7 && d.live.len() == 8, "ids must be 1, 2, 3, ...");

    for (int value = 1; value <= 5; value++)
    {
        note('0' + (char)value);
        note(':');
        d.emit(value);
        note(' ');
        assert(d.pending.len() == 0, "pending must be merged after the outermost emit");
        foreach (l : d.live) assert(!l.removed, "removed listeners must be compacted");
    }
    String log = (String)g_log[:g_log_len];
    io::printfn("log: %s", log);
    assert(log == "1:ABCVRXOO 2:ACRXOO 3:ACRXOO 4:ACRX(ACRXOON)N 5:ACRXN ", "wrong dispatch log");

    // Устаревшие id безопасны.
    assert(!d.unsubscribe(b.sub) && !d.unsubscribe(v.sub) && !d.unsubscribe(999));
    assert(d.unsubscribe(g_newbie.sub));
    assert(d.unsubscribe_owner(&a) == 1);
    assert(d.live.len() == 3);

    // Отписка из pending до слияния.
    d.depth = 1;                       // имитируем «мы внутри рассылки»
    uint late = d.subscribe(&plain, &b);
    assert(d.pending.len() == 1 && d.unsubscribe(late) && d.pending.len() == 0);
    d.depth = 0;

    io::printfn("calls: A=%d B=%d C=%d V=%d R=%d X=%d O=%d N=%d",
                a.calls, b.calls, c.calls, v.calls, r.calls, x.calls, o.calls, g_newbie.calls);
    io::printfn("live=%d next_id=%d", d.live.len(), d.next_id);
    io::printn("listener lifetime: all checks passed");
}
