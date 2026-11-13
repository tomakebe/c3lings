// =====================================================================
//  e1506 · Финал главы: консоль разработчика, cvars и профилировщик
// =====================================================================
//
//  Сначала прочитайте engine/docs/15_profiling_debugging.md
//  (раздел «Консоль и cvars»).
//
//  Консоль (Quake `~`, Unreal `` ` ``, Source) — это центр всех
//  отладочных инструментов: из неё включают профилировщик, меняют
//  параметры физики на лету, телепортируются и пишут скрипты из
//  команд. Она состоит из трёх частей:
//
//  1. Токенизатор. Строка `sim_steps 4; echo "hello world"` — это две
//     инструкции, разделённые `;`. Токены разделяются пробелами, текст
//     в кавычках — один токен (кавычки в него не входят), `;` внутри
//     кавычек — обычный символ. Токены — срезы исходной строки, без
//     аллокаций.
//
//  2. Cvars (console variables) — типизированные именованные настройки
//     с дефолтом, диапазоном, флагами и справкой. Ключевой приём:
//     регистрация возвращает УКАЗАТЕЛЬ на cvar, и игра каждый кадр
//     читает `cv_steps.i` — никакого поиска по строке в горячем пути.
//     Поэтому cvars лежат в массиве фиксированного размера: указатели на
//     элементы List были бы инвалидированы при его росте.
//     Флаги: READONLY (нельзя менять из консоли), CHEAT (только при
//     sv_cheats 1 — так в Source/Quake защищают мультиплеер).
//
//  3. Команды: имя + обработчик `fn void(Console*, String[] args)`.
//
//  Правила `execute` для каждой инструкции:
//     * пустая инструкция — пропустить;
//     * имя команды — вызвать обработчик с args = токены без имени;
//     * имя cvar без аргументов — напечатать "<name> = <value>";
//     * имя cvar с аргументом — set_cvar (ошибки печатаются, см. ниже);
//     * иначе — "unknown command: <name>".
//
//  set_cvar печатает ошибку и НЕ меняет значение:
//     "<name> is read-only" / "<name> is cheat protected" /
//     "bad value for <name>: <text>"
//  Числа зажимаются в [min, max]. bool принимает 0/1/true/false/on/off.
//
//  Автодополнение: все имена команд и cvar'ов с данным префиксом,
//  отсортированные по алфавиту.
//
//  Всё связано вместе: cvars управляют симуляцией, профилировщик
//  меряет кадр (подставные часы), команда prof_dump печатает зоны,
//  отсортированные по self-времени.
//
//  ЗАДАЧА: реализуйте `tokenize`, `parse_bool`, `Console.set_cvar`,
//  `Console.execute_tokens` и `Console.complete` (TODO).
//
import std::io, std::sort;

// ================================================================ profiler (готов)
ulong g_now;
fn void work(ulong t) { g_now += t; }

const int MAX_ZONES = 64;
struct ZoneEvent { String name; ulong begin; ulong end; int depth; }
struct ZoneStat { String name; int calls; ulong total; ulong self_time; }

struct Profiler
{
    bool enabled;
    ZoneEvent[MAX_ZONES] events;
    int count;
    int[8] stack;
    int depth;
}
Profiler g_prof;

fn void Profiler.begin(&self, String name)
{
    if (!self.enabled) return;
    int idx = self.count++;
    self.events[idx] = { .name = name, .begin = g_now, .depth = self.depth };
    self.stack[self.depth++] = idx;
}
fn void Profiler.end(&self)
{
    if (!self.enabled) return;
    self.events[self.stack[--self.depth]].end = g_now;
}

macro @zone(String name; @body)
{
    g_prof.begin(name);
    defer g_prof.end();
    @body();
}

<* Плоская статистика по именам: total и self (минус прямые дети). *>
fn int Profiler.flat_stats(&self, ZoneStat[] out)
{
    int n = 0;
    for (int i = 0; i < self.count; i++)
    {
        ZoneEvent e = self.events[i];
        ulong dur = e.end - e.begin;
        ulong children = 0;
        for (int j = i + 1; j < self.count && self.events[j].depth > e.depth; j++)
        {
            if (self.events[j].depth == e.depth + 1) children += self.events[j].end - self.events[j].begin;
        }
        int k = 0;
        while (k < n && out[k].name != e.name) k++;
        if (k == n) out[n++] = { .name = e.name };
        out[k].calls++;
        out[k].total += dur;
        out[k].self_time += dur - children;
    }
    sort::quicksort(out[:n], fn int(ZoneStat a, ZoneStat b)
        => a.self_time != b.self_time ? (a.self_time > b.self_time ? -1 : 1) : a.name.compare_to(b.name));
    return n;
}

// ================================================================ console
enum CVarKind : char { INT, FLOAT, BOOL }

const uint CVAR_READONLY = 1;
const uint CVAR_CHEAT    = 2;

struct CVar
{
    String name;
    String help;
    CVarKind kind;
    uint flags;
    int i;
    float f;
    bool b;
    float min;
    float max;
}

alias CommandFn = fn void(Console*, String[]);

struct Command
{
    String name;
    String help;
    CommandFn handler;
}

const int MAX_CVARS = 16;
const int MAX_CMDS = 16;
const int MAX_TOKENS = 8;

struct Console
{
    CVar[MAX_CVARS] cvars;     // фиксированный массив: указатели стабильны
    int cvar_count;
    Command[MAX_CMDS] cmds;
    int cmd_count;
    CVar* cheats;
}

fn CVar* Console.add_cvar(&self, CVar cv)
{
    assert(self.cvar_count < MAX_CVARS);
    CVar* p = &self.cvars[self.cvar_count++];
    *p = cv;
    return p;
}

fn CVar* Console.register_int(&self, String name, int value, int min, int max, String help, uint flags = 0)
    => self.add_cvar({ .name = name, .help = help, .kind = INT, .flags = flags, .i = value, .min = min, .max = max });
fn CVar* Console.register_float(&self, String name, float value, float min, float max, String help, uint flags = 0)
    => self.add_cvar({ .name = name, .help = help, .kind = FLOAT, .flags = flags, .f = value, .min = min, .max = max });
fn CVar* Console.register_bool(&self, String name, bool value, String help, uint flags = 0)
    => self.add_cvar({ .name = name, .help = help, .kind = BOOL, .flags = flags, .b = value });

fn void Console.register_cmd(&self, String name, CommandFn handler, String help)
{
    assert(self.cmd_count < MAX_CMDS);
    self.cmds[self.cmd_count++] = { name, help, handler };
}

fn CVar* Console.find_cvar(&self, String name)
{
    foreach (&cv : self.cvars[:self.cvar_count]) if (cv.name == name) return cv;
    return null;
}

fn Command* Console.find_cmd(&self, String name)
{
    foreach (&c : self.cmds[:self.cmd_count]) if (c.name == name) return c;
    return null;
}

fn void CVar.print(&self)
{
    switch (self.kind)
    {
        case INT:   io::printfn("%s = %d", self.name, self.i);
        case FLOAT: io::printfn("%s = %.2f", self.name, self.f);
        case BOOL:  io::printfn("%s = %s", self.name, self.b ? "1" : "0");
    }
}

<*
 Разобрать одну инструкцию, начиная с начала `line`: записать токены в
 `out` (срезы `line`, кавычки не входят в токен), остановиться на `;`
 вне кавычек или на конце строки. В *consumed записать, сколько
 символов строки обработано (включая `;`). Вернуть число токенов.
 Пробелы и табуляции — разделители. Незакрытая кавычка тянется до
 конца строки. Больше MAX_TOKENS токенов — лишние отбросить.
*>
fn int tokenize(String line, String[] out, usz* consumed)
{
    // TODO
    *consumed = line.len;
    return 0;
}

excuse BAD_BOOL;

<* 0/1/true/false/on/off; иначе — ошибка BAD_BOOL. *>
fn bool? parse_bool(String s)
{
    // TODO
    return BAD_BOOL~;
}

<*
 Проверить флаги (READONLY; CHEAT при выключенном self.cheats.b),
 разобрать значение по типу cvar, зажать числа в [min, max] и записать.
 При ошибке напечатать сообщение (см. шапку) и вернуть false.
*>
fn bool Console.set_cvar(&self, CVar* cv, String text)
{
    // TODO
    return false;
}

<* Выполнить одну разобранную инструкцию (правила — в шапке). *>
fn void Console.execute_tokens(&self, String[] toks)
{
    // TODO
}

fn void Console.execute(&self, String line)
{
    io::printfn("> %s", line);
    String rest = line;
    while (rest.len > 0)
    {
        String[MAX_TOKENS] toks;
        usz used;
        int n = tokenize(rest, &toks, &used);
        assert(used > 0, "tokenize must make progress");
        self.execute_tokens(toks[:n]);
        rest = rest[used..];
    }
}

<*
 Записать в `out` имена всех команд и cvar'ов, начинающиеся с `prefix`,
 отсортировать по алфавиту, вернуть количество.
*>
fn int Console.complete(&self, String prefix, String[] out)
{
    // TODO
    return 0;
}

// ================================================================ commands
fn void cmd_echo(Console* con, String[] args)
{
    foreach (i, a : args) io::printf(i == 0 ? "%s" : "|%s", a);
    io::printn();
}

fn void cmd_prof_dump(Console* con, String[] args)
{
    ZoneStat[16] stats;
    int n = g_prof.flat_stats(&stats);
    io::printfn("%d zones:", n);
    foreach (s : stats[:n]) io::printfn("  %-8s calls=%d total=%d self=%d", s.name, s.calls, s.total, s.self_time);
}

fn void cmd_help(Console* con, String[] args)
{
    String[32] names;
    int n = con.complete(args.len > 0 ? args[0] : "", &names);
    foreach (name : names[:n])
    {
        if (Command* c = con.find_cmd(name)) io::printfn("  %-13s %s", name, c.help);
        if (CVar* cv = con.find_cvar(name)) io::printfn("  %-13s %s", name, cv.help);
    }
}

// ================================================================ game
CVar* cv_steps;
CVar* cv_timescale;
CVar* cv_god;
CVar* cv_prof;

int g_hp = 100;

fn void game_frame()
{
    g_prof.count = 0;
    g_prof.enabled = cv_prof.b;
    @zone("frame")
    {
        @zone("physics")
        {
            for (int i = 0; i < cv_steps.i; i++) @zone("step") { work(3); };
        };
        @zone("ai")
        {
            work((ulong)(10 * cv_timescale.f));
            if (!cv_god.b) g_hp -= 10;
        };
        @zone("render") { work(4); };
        work(1);
    };
}

fn void main()
{
    Console con;
    con.cheats  = con.register_bool("sv_cheats", false, "allow cheat cvars");
    cv_steps    = con.register_int("sim_steps", 2, 1, 8, "physics substeps per frame");
    cv_timescale = con.register_float("timescale", 1.0, 0.1, 4.0, "game speed");
    cv_god      = con.register_bool("god", false, "invulnerability", CVAR_CHEAT);
    cv_prof     = con.register_bool("prof_enabled", false, "capture profiler zones");
    con.register_int("version", 15, 0, 100, "engine version", CVAR_READONLY);
    con.register_cmd("echo", &cmd_echo, "print arguments");
    con.register_cmd("prof_dump", &cmd_prof_dump, "print zones by self time");
    con.register_cmd("help", &cmd_help, "list commands and cvars");

    // --- токенизатор
    String[MAX_TOKENS] t;
    usz used;
    assert(tokenize("  a  bb\tccc ", &t, &used) == 3 && t[1] == "bb" && t[2] == "ccc" && used == 12);
    assert(tokenize("say \"x ; y\" z; next", &t, &used) == 3 && t[1] == "x ; y" && t[2] == "z" && used == 14);
    assert(tokenize(";", &t, &used) == 0 && used == 1);
    assert(tokenize("a \"open", &t, &used) == 2 && t[1] == "open");
    assert(tokenize("1 2 3 4 5 6 7 8 9 10", &t, &used) == MAX_TOKENS && used == 20);

    // --- cvars
    assert(!con.set_cvar(cv_steps, "x") && cv_steps.i == 2);
    assert(con.set_cvar(cv_steps, "100") && cv_steps.i == 8, "clamped to max");
    assert(con.set_cvar(cv_steps, "2"));
    assert(!con.set_cvar(cv_god, "1") && !cv_god.b);
    assert(parse_bool("on")!! && !parse_bool("off")!!);
    io::printn("-- self-tests passed --");

    String[] script = {
        "help",
        "sim_steps",
        "sim_steps 4; god 1",
        "sv_cheats on; god 1;; timescale 0.5",
        "version 16",
        "timescale fast",
        "echo \"hello world\" twice;echo done",
        "frobnicate 3",
        "prof_enabled 1",
    };
    foreach (line : script) con.execute(line);

    for (int f = 0; f < 3; f++) game_frame();
    assert(g_hp == 100, "god mode was on");
    assert(g_now == 3 * (4 * 3 + 5 + 4 + 1));

    con.execute("prof_dump");
    con.execute("sim_steps 1; god off");
    game_frame();
    assert(g_hp == 90);
    con.execute("prof_dump");

    String[8] comp;
    int n = con.complete("s", &comp);
    io::printfn("complete 's': %s", comp[:n]);
    assert(n == 2 && comp[0] == "sim_steps" && comp[1] == "sv_cheats");
    n = con.complete("prof", &comp);
    io::printfn("complete 'prof': %s", comp[:n]);
    assert(con.complete("zzz", &comp) == 0);
    io::printn("console ok");
}
