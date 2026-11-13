// =====================================================================
//  e1502 · Профилировщик: дерево вызовов, self/total, история кадров
// =====================================================================
//
//  Сначала прочитайте engine/docs/15_profiling_debugging.md
//  (раздел «Агрегация: от событий к дереву»).
//
//  Сырые события зон (из e1501) — это «временная шкала». Её удобно
//  смотреть в Tracy, но для оверлея в игре нужна АГРЕГАЦИЯ: одинаковые
//  зоны на одном и том же пути вызовов сливаются в один узел дерева.
//
//      события (preorder, depth)          дерево
//      frame        d0                    frame      calls=1 total=34
//        physics    d1                      physics  calls=1 total=15
//          step     d2   \                    step   calls=3 total=15
//          step     d2    > сливаются
//          step     d2   /
//        render     d1                      render   calls=1 total=7
//
//  Две важнейшие метрики:
//    * total (inclusive) — время узла вместе с детьми;
//    * self  (exclusive) — total минус сумма total детей. Именно self
//      показывает, ГДЕ на самом деле горит процессор.
//
//  Как построить дерево за один проход: события идут в порядке открытия
//  и знают свою глубину, значит, родитель события глубины d — это узел,
//  в который мы последним «вошли» на глубине d-1. Держим массив
//  path[depth] = индекс узла. Узел-корень (индекс 0) — фиктивный.
//
//  Дети хранятся интрузивным списком first_child/next_sibling (индексы,
//  а не указатели: массив узлов можно копировать и сбрасывать целиком).
//  Новых детей добавляйте В КОНЕЦ списка, чтобы порядок печати совпадал
//  с порядком первого появления.
//
//  Второе: история кадров. Одно измерение ничего не значит — нужны
//  min/avg/max за последние N кадров. Это кольцевой буфер фиксированного
//  размера: push перезаписывает самый старый элемент.
//
//  ЗАДАЧА: реализуйте `ZoneTree.find_or_add_child`, `ZoneTree.add_event`,
//  `ZoneTree.compute_self`, `History.push`, `History.stats` (TODO).
//
import std::io;

// ------------------------------------------------------------ profiler (готов, из e1501)
alias ClockFn = fn ulong();
ulong g_now;
fn ulong fake_clock() => g_now;
fn void work(ulong ticks) { g_now += ticks; }

const int MAX_EVENTS = 64;
const int MAX_DEPTH  = 8;

struct ZoneEvent { String name; ulong begin; ulong end; int depth; }

struct Profiler
{
    ClockFn clock;
    ZoneEvent[MAX_EVENTS] events;
    int count;
    int[MAX_DEPTH] stack;
    int depth;
}
Profiler g_prof;

fn void Profiler.begin(&self, String name)
{
    assert(self.count < MAX_EVENTS && self.depth < MAX_DEPTH);
    int idx = self.count++;
    self.events[idx] = { .name = name, .begin = self.clock(), .depth = self.depth };
    self.stack[self.depth++] = idx;
}
fn void Profiler.end(&self) => self.events[self.stack[--self.depth]].end = self.clock();

macro @zone(String name; @body)
{
    g_prof.begin(name);
    defer g_prof.end();
    @body();
}

// ------------------------------------------------------------ aggregation
const int MAX_NODES = 32;
const int NONE = -1;

struct ZoneNode
{
    String name;
    int parent;
    int first_child;
    int next_sibling;
    int calls;
    ulong total;
    ulong self_time;
}

struct ZoneTree
{
    ZoneNode[MAX_NODES] nodes;   // nodes[0] — фиктивный корень
    int count;
    int[MAX_DEPTH + 1] path;     // path[d] — узел, куда вошли на глубине d-1; path[0] = корень
}

fn void ZoneTree.reset(&self)
{
    self.count = 1;
    self.nodes[0] = { .name = "<root>", .parent = NONE, .first_child = NONE, .next_sibling = NONE };
    self.path[0] = 0;
}

<*
 Найти среди детей `parent` узел с именем `name`; если нет — создать
 его (calls = 0, total = 0) и прицепить В КОНЕЦ списка детей.
 Вернуть индекс узла.
*>
fn int ZoneTree.find_or_add_child(&self, int parent, String name)
{
    // TODO
    return 0;
}

<*
 Учесть одно событие: родитель = path[e.depth], узел = find_or_add_child,
 calls += 1, total += длительность, path[e.depth + 1] = узел.
*>
fn void ZoneTree.add_event(&self, ZoneEvent e)
{
    // TODO
}

<*
 Для всех узлов кроме корня: self_time = total - сумма total детей.
*>
fn void ZoneTree.compute_self(&self)
{
    // TODO
}

fn void ZoneTree.print_node(&self, int node, int depth)
{
    for (int c = self.nodes[node].first_child; c != NONE; c = self.nodes[c].next_sibling)
    {
        ZoneNode* n = &self.nodes[c];
        for (int d = 0; d < depth; d++) io::print("  ");
        io::printfn("%s calls=%d total=%d self=%d", n.name, n.calls, n.total, n.self_time);
        self.print_node(c, depth + 1);
    }
}

// ------------------------------------------------------------ frame history
const int HISTORY = 4;

struct History
{
    ulong[HISTORY] samples;
    int head;      // куда писать следующий
    int count;     // сколько валидных (<= HISTORY)
}

struct Stats { ulong min; ulong max; ulong avg; }

<* Записать сэмпл, перезаписав самый старый при переполнении. *>
fn void History.push(&self, ulong v)
{
    // TODO
}

<* min/max/avg (целочисленное деление) по валидным сэмплам. *>
fn Stats History.stats(&self)
{
    // TODO
    return {};
}

// ------------------------------------------------------------ "game"
fn void simulate_frame(int frame)
{
    @zone("frame")
    {
        work(1);
        @zone("physics")
        {
            for (int i = 0; i < 2 + frame % 2; i++) @zone("step") { work(4); };
        };
        @zone("ai")
        {
            @zone("path") { work((ulong)(2 + frame)); };
            work(1);
            @zone("path") { work(3); };
        };
        @zone("render") { @zone("cull") { work(2); }; work(5); };
    };
}

fn void main()
{
    ZoneTree tree;
    History hist;
    for (int frame = 0; frame < 6; frame++)
    {
        g_prof = { .clock = &fake_clock };
        simulate_frame(frame);
        tree.reset();
        foreach (e : g_prof.events[:g_prof.count]) tree.add_event(e);
        tree.compute_self();
        hist.push(tree.nodes[1].total);
        if (frame == 0)
        {
            assert(tree.count == 8, "nodes: root frame physics step ai path render cull");
            assert(tree.nodes[3].name == "step" && tree.nodes[3].calls == 2 && tree.nodes[3].total == 8);
            assert(tree.nodes[5].name == "path" && tree.nodes[5].calls == 2 && tree.nodes[5].self_time == 5);
            assert(tree.nodes[4].self_time == 1, "ai self = 6 - 5");
            assert(tree.nodes[1].self_time == 1);
        }
        g_now = 0;
    }
    io::printn("last frame:");
    tree.print_node(0, 1);

    assert(hist.count == HISTORY);
    Stats s = hist.stats();
    io::printfn("history: min=%d avg=%d max=%d", s.min, s.avg, s.max);
    assert(s.min == 24 && s.max == 31 && s.avg == 27);

    History h2;
    h2.push(10);
    h2.push(20);
    Stats s2 = h2.stats();
    assert(s2.min == 10 && s2.max == 20 && s2.avg == 15, "only valid samples count");
    io::printn("zone tree ok");
}
