// =====================================================================
//  e1503 · Логирование с категориями и собственный assert
// =====================================================================
//
//  Сначала прочитайте engine/docs/15_profiling_debugging.md
//  (разделы «Логирование» и «Assert'ы»).
//
//  Лог движка — это не `printf`. Требования к нему:
//
//    1. Категории (CORE, RENDER, PHYSICS, AI...) и уровни (ERROR, WARN,
//       INFO, VERBOSE) с порогом НА КАТЕГОРИЮ: отлаживаете физику —
//       включаете PHYSICS=VERBOSE, остальное молчит.
//    2. Отфильтрованное сообщение почти ничего не стоит: аргументы НЕ
//       вычисляются и строка НЕ форматируется. В C это делают макросом
//       `if (enabled) log_impl(...)`. В C3 аргументы макроса ленивые:
//       `...$vaarg` подставляет сами выражения, поэтому если ветка
//       `if` не выполнилась, `expensive()` не будет вызвана вовсе.
//    3. Несколько приёмников (sinks): консоль, файл, кольцевой буфер
//       последних сообщений, который сбрасывается в crash dump.
//    4. Форматирование в буфер на стеке (`io::bprintf`), без кучи.
//
//  Собственный assert. Стандартный `assert` просто роняет программу.
//  Движковые assert'ы богаче:
//
//      if (!@check(hp >= 0, "negative hp")) return;
//
//    * текст выражения через `$stringify(#expr)` и функция через `$$FUNC`;
//    * возвращает bool — можно «мягко» обработать ошибку в релизе;
//    * анти-спам: каждое МЕСТО вызова сообщает о себе один раз.
//      Трюк: `static bool reported;` внутри макроса — у каждой точки
//      раскрытия макроса своя static-переменная (проверено в 0.8.5).
//      Это аналог кнопки «Ignore always» в диалоге assert'а Unreal.
//    * выражение вычисляется ровно один раз (#expr используем 1 раз!).
//
//  ЗАДАЧА: реализуйте `Logger.enabled`, макрос `@log` и макрос `@check`
//  (TODO). Формат сообщения @check:
//      "check failed: <выражение> (<msg>) in <функция>"
//  категория CORE, уровень ERROR.
//
import std::io;

enum Category : char { CORE, RENDER, PHYSICS, AI }
enum Level    : char { ERROR, WARN, INFO, VERBOSE }

alias SinkFn = fn void(Category, Level, String);

struct Logger
{
    Level[Category::len] threshold;
    SinkFn[4] sinks;
    int sink_count;
    int formatted;              // сколько сообщений было отформатировано
    int[Level::len] emitted;    // сколько ушло в sinks, по уровням
}

Logger g_log;
int g_check_failures;

fn void Logger.add_sink(&self, SinkFn sink) => self.sinks[self.sink_count++] = sink;

fn void Logger.dispatch(&self, Category cat, Level lvl, String msg)
{
    self.emitted[lvl.ordinal]++;
    foreach (sink : self.sinks[:self.sink_count]) sink(cat, lvl, msg);
}

<* true, если сообщение уровня lvl в категории cat проходит порог. *>
fn bool Logger.enabled(&self, Category cat, Level lvl)
{
    // TODO
    return false;
}

<*
 Если g_log.enabled(cat, lvl): отформатировать сообщение в char[128] на
 стеке через io::bprintf(&buf, fmt, ...$vaarg), увеличить
 g_log.formatted и вызвать g_log.dispatch. Иначе — ничего не делать
 (и не вычислять аргументы!).
*>
macro @log(Category cat, Level lvl, String fmt, ...)
{
    // TODO
}

<*
 Вычислить #expr ОДИН раз. Если истинно — вернуть true. Иначе:
 g_check_failures++, и если это место ещё не сообщало (static bool) —
 залогировать CORE/ERROR "check failed: <expr> (<msg>) in <func>".
 Вернуть false.
*>
macro bool @check(#expr, String msg)
{
    // TODO
    return true;
}

// ------------------------------------------------------------ sinks
fn void stdout_sink(Category cat, Level lvl, String msg)
{
    io::printfn("[%s:%s] %s", cat, lvl, msg);
}

const int RING = 4;
struct RingLog
{
    char[64][RING] text;
    usz[RING] len;
    int head;
    int count;
}
RingLog g_ring;

fn void ring_sink(Category cat, Level lvl, String msg)
{
    char[] dst = &g_ring.text[g_ring.head];
    usz n = msg.len < dst.len ? msg.len : dst.len;
    dst[:n] = msg[:n];
    g_ring.len[g_ring.head] = n;
    g_ring.head = (g_ring.head + 1) % RING;
    if (g_ring.count < RING) g_ring.count++;
}

fn void ring_dump()
{
    io::printn("--- crash dump (last messages) ---");
    int start = (g_ring.head - g_ring.count + RING) % RING;
    for (int i = 0; i < g_ring.count; i++)
    {
        int idx = (start + i) % RING;
        io::printfn("  %s", (String)g_ring.text[idx][:g_ring.len[idx]]);
    }
}

// ------------------------------------------------------------ "game"
int g_expensive_calls;
fn int expensive_stat()
{
    g_expensive_calls++;
    return 42;
}

struct Unit { String name; int hp; }

fn int apply_damage(Unit* u, int dmg)
{
    if (!@check(u.hp > 0, "damage to dead unit")) return 0;
    u.hp -= dmg;
    @log(AI, INFO, "%s takes %d, hp=%d", u.name, dmg, u.hp);
    return dmg;
}

fn void main()
{
    g_log.threshold = { [Category.CORE] = INFO, [Category.RENDER] = WARN,
                        [Category.PHYSICS] = VERBOSE, [Category.AI] = ERROR };
    g_log.add_sink(&stdout_sink);
    g_log.add_sink(&ring_sink);

    assert(g_log.enabled(PHYSICS, VERBOSE));
    assert(!g_log.enabled(RENDER, INFO));
    assert(g_log.enabled(RENDER, ERROR));
    assert(!g_log.enabled(AI, WARN));

    @log(CORE, INFO, "engine start, build %d", 7);
    @log(RENDER, INFO, "drawcalls=%d", expensive_stat());     // отфильтровано
    @log(RENDER, WARN, "texture %s missing", "rock.png");
    @log(PHYSICS, VERBOSE, "broadphase pairs=%d", expensive_stat());
    @log(AI, VERBOSE, "%d", expensive_stat());                // отфильтровано
    assert(g_expensive_calls == 1, "filtered messages must not evaluate their arguments");
    assert(g_log.formatted == 3);

    Unit orc = { "orc", 10 };
    int dealt;
    for (int i = 0; i < 5; i++) dealt += apply_damage(&orc, 4);
    assert(dealt == 12 && orc.hp == -2);
    assert(g_check_failures == 2, "two failed checks");

    int side_effects;
    assert(@check(++side_effects == 1, "once"), "expression is evaluated once");
    assert(side_effects == 1);
    assert(!@check(side_effects == 0, "different call site reports again"));
    assert(g_check_failures == 3);

    io::printfn("emitted: error=%d warn=%d info=%d verbose=%d",
        g_log.emitted[0], g_log.emitted[1], g_log.emitted[2], g_log.emitted[3]);
    ring_dump();
    io::printn("logging ok");
}
