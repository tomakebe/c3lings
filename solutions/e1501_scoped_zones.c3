// =====================================================================
//  e1501 · Профилировщик: зоны с областью видимости
// =====================================================================
//
//  Сначала прочитайте engine/docs/15_profiling_debugging.md
//  (разделы «Инструментирующий профилировщик» и «Часы»).
//
//  Инструментирующий профилировщик (Tracy, Optick, Remotery, встроенные
//  профилировщики Unreal/Unity) работает так: код размечается «зонами».
//  Зона — это именованный интервал времени: в начале мы записываем
//  отметку времени, в конце — вторую. Зоны вложены друг в друга так же,
//  как вложены вызовы функций, поэтому из них получается дерево:
//
//      frame  |=========================================|
//      input  |==|
//      update     |=======================|
//      physics    |=============|
//      step       |===|===|===|
//      render                              |==========|
//
//  Главное правило: КАЖДЫЙ begin обязан иметь парный end, даже если из
//  середины зоны сделали `return` или `break`. В C++ это делают RAII-
//  объектом (`ZoneScoped` в Tracy). В C3 то же самое даёт `defer`
//  внутри макроса с trailing-блоком:
//
//      macro @zone(String name; @body)
//      {
//          g_prof.begin(name);
//          defer g_prof.end();
//          @body();
//      }
//
//      @zone("physics")
//      {
//          ...                 // любой return отсюда всё равно вызовет end()
//      };
//
//  `return` внутри @body возвращает из ОБЪЕМЛЮЩЕЙ функции (тело макроса
//  встраивается), а `defer` макроса срабатывает при выходе из него.
//
//  Время берётся не из системных часов, а через указатель на функцию
//  `ClockFn`. В игре это был бы `rdtsc`/`QueryPerformanceCounter`, а в
//  тестах — подставные часы, которые двигаем руками. Так вывод
//  профилировщика детерминирован и его можно проверять.
//
//  Буфер событий фиксированного размера (никаких аллокаций в горячем
//  пути!). Если он переполнился, зона не записывается, но счётчик
//  `dropped` растёт, а стек остаётся сбалансированным: в стек кладём -1,
//  и end() для такой зоны ничего не пишет.
//
//  ЗАДАЧА: реализуйте `Profiler.begin`, `Profiler.end` и макрос `@zone`
//  (места помечены TODO). Программа сама проверит себя и напечатает
//  временную шкалу кадра.
//
import std::io;

alias ClockFn = fn ulong();

// ------------------------------------------------------------ fake clock
ulong g_now;
fn ulong fake_clock() => g_now;
fn void work(ulong ticks) { g_now += ticks; }

// ------------------------------------------------------------ profiler
const int MAX_EVENTS = 16;
const int MAX_DEPTH  = 8;

struct ZoneEvent
{
    String name;
    ulong  begin;
    ulong  end;
    int    depth;
}

struct Profiler
{
    ClockFn clock;
    ZoneEvent[MAX_EVENTS] events;  // в порядке открытия (preorder)
    int count;
    int[MAX_DEPTH] stack;          // индексы открытых событий, -1 = отброшено
    int depth;
    int dropped;
}

Profiler g_prof;

fn void Profiler.reset(&self, ClockFn clock)
{
    *self = {};
    self.clock = clock;
}

<*
 Открыть зону: записать событие (name, begin = clock(), depth = текущая
 глубина), положить его индекс в стек. Если буфер полон — dropped++ и
 положить в стек -1.
*>
fn void Profiler.begin(&self, String name)
{
    assert(self.depth < MAX_DEPTH, "zone stack overflow");
    if (self.count == MAX_EVENTS)
    {
        self.dropped++;
        self.stack[self.depth++] = -1;
        return;
    }
    int idx = self.count++;
    self.events[idx] = { .name = name, .begin = self.clock(), .depth = self.depth };
    self.stack[self.depth++] = idx;
}

<*
 Закрыть самую внутреннюю открытую зону: снять индекс со стека и, если
 он не -1, записать end = clock().
*>
fn void Profiler.end(&self)
{
    assert(self.depth > 0, "end() without begin()");
    int idx = self.stack[--self.depth];
    if (idx >= 0) self.events[idx].end = self.clock();
}

macro @zone(String name; @body)
{
    g_prof.begin(name);
    defer g_prof.end();
    @body();
}

// ------------------------------------------------------------ "game"
fn int find_path(int target)
{
    @zone("find_path")
    {
        work(3);
        if (target < 0) return -1;      // ранний выход — зона всё равно закроется
        work(4);
    };
    return target * 2;
}

fn void run_frame()
{
    @zone("frame")
    {
        @zone("input") { work(2); };
        @zone("update")
        {
            @zone("physics")
            {
                for (int i = 0; i < 3; i++)
                {
                    @zone("step") { work(5); };
                }
            };
            @zone("ai")
            {
                assert(find_path(-1) == -1);
                assert(find_path(10) == 20);
            };
        };
        @zone("render") { work(7); };
    };
}

fn void print_timeline(Profiler* p)
{
    for (int i = 0; i < p.count; i++)
    {
        ZoneEvent e = p.events[i];
        for (int d = 0; d < e.depth; d++) io::print("  ");
        io::printfn("%s [%d..%d] = %d", e.name, e.begin, e.end, e.end - e.begin);
    }
}

fn void main()
{
    g_prof.reset(&fake_clock);
    run_frame();

    assert(g_prof.depth == 0, "unbalanced zones");
    assert(g_prof.count == 11, "expected 11 zones in the frame");
    assert(g_prof.events[0].name == "frame" && g_prof.events[0].end == 34);
    assert(g_prof.events[7].name == "ai" && g_prof.events[7].depth == 2);
    assert(g_prof.events[8].end - g_prof.events[8].begin == 3, "early-return zone must close");
    print_timeline(&g_prof);

    // Переполнение: 20 зон при буфере на 16 событий.
    g_prof.reset(&fake_clock);
    @zone("burst")
    {
        for (int i = 0; i < 20; i++) @zone("tick") { work(1); };
    };
    assert(g_prof.depth == 0);
    assert(g_prof.count == MAX_EVENTS);
    assert(g_prof.events[0].end == g_now, "outer zone still closes after overflow");
    io::printfn("burst: recorded=%d dropped=%d", g_prof.count, g_prof.dropped);
    io::printn("profiler ok");
}
