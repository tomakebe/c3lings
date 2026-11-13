// =====================================================================
//  E0505 · Планировщик систем
// =====================================================================
//
//  Сначала прочитайте engine/docs/05_ecs.md (разделы 5–6).
//
//  Каждая система объявляет, какие компоненты ЧИТАЕТ и какие ПИШЕТ
//  (битовые маски), и, при необходимости, явные ограничения порядка
//  «after»: список систем, которые должны выполниться раньше неё.
//
//  Две системы КОНФЛИКТУЮТ, если одна пишет то, что другая читает или
//  пишет:  (a.writes & (b.reads | b.writes)) || (b.writes & (a.reads | a.writes)).
//  Неконфликтующие системы можно выполнять одновременно (в одном этапе).
//
//  Построение плана (build) — в два шага:
//
//    1. ПОРЯДОК. Явные ограничения образуют граф (ребро j -> i для
//       каждого j из i.after). Топологическая сортировка (алгоритм Кана):
//       среди систем, у которых все «предшественники» уже взяты, всегда
//       берём систему с МЕНЬШИМ индексом регистрации — порядок
//       детерминирован. Если взять некого, а системы остались — цикл,
//       build() возвращает false. Результат: order[] и rank[i] — место
//       системы i в этом порядке.
//
//    2. ЭТАПЫ. Система i должна идти после j, если j -> i явно ИЛИ если
//       они конфликтуют и rank[j] < rank[i]. Все такие рёбра идут
//       «вперёд» по order, поэтому циклов быть не может, а этап — это
//       длина самого длинного пути:
//           stage[i] = max(stage[j] + 1) по всем таким j (или 0).
//       Считайте, обходя системы в порядке order.
//
//  Проверка корректности плана: внутри этапа системы не конфликтуют,
//  поэтому их можно выполнять в ЛЮБОМ порядке (или параллельно). main
//  выполняет симуляцию дважды — с прямым и обратным порядком внутри
//  этапов — и результаты обязаны совпасть.
//
//  ЗАДАЧА: реализуйте conflicts и Scheduler.build.
//
import std::io;

const uint POS    = 1 << 0;
const uint VEL    = 1 << 1;
const uint INPUT  = 1 << 2;
const uint HP     = 1 << 3;
const uint AI     = 1 << 4;
const uint RENDER = 1 << 5;
const uint CAMERA = 1 << 6;

const int MAX_SYSTEMS = 16;

struct Sim
{
    int[4] pos;
    int[4] vel;
    int input;
    int tick;
    int[4] hp;
    int[4] ai_target;
    int camera;
    long render_hash;
}

alias SystemFn = fn void(Sim* s);

struct SystemDesc
{
    String name;
    uint reads;
    uint writes;
    int[4] after;
    int after_count;
    SystemFn run;
}

fn bool conflicts(SystemDesc* a, SystemDesc* b)
{
    return (a.writes & (b.reads | b.writes)) != 0 || (b.writes & (a.reads | a.writes)) != 0;
}

struct Scheduler
{
    SystemDesc[MAX_SYSTEMS] systems;
    int count;
    int[MAX_SYSTEMS] stage;
    int stage_count;
}

fn int Scheduler.add(&self, String name, uint reads, uint writes, SystemFn run, int[] after = {})
{
    SystemDesc* d = &self.systems[self.count];
    *d = { .name = name, .reads = reads, .writes = writes, .run = run };
    foreach (a : after) d.after[d.after_count++] = a;
    return self.count++;
}

fn bool Scheduler.build(&self)
{
    int n = self.count;
    bool[MAX_SYSTEMS] taken;
    int[MAX_SYSTEMS] order;
    int[MAX_SYSTEMS] rank;
    // 1. Топологическая сортировка явных ограничений.
    for (int pos = 0; pos < n; pos++)
    {
        int pick = -1;
        for (int i = 0; i < n && pick < 0; i++)
        {
            if (taken[i]) continue;
            bool ready = true;
            SystemDesc* d = &self.systems[i];
            for (int k = 0; k < d.after_count; k++) if (!taken[d.after[k]]) ready = false;
            if (ready) pick = i;
        }
        if (pick < 0) return false;
        taken[pick] = true;
        order[pos] = pick;
        rank[pick] = pos;
    }
    // 2. Этапы: самый длинный путь по явным рёбрам и конфликтам.
    self.stage_count = 0;
    for (int pos = 0; pos < n; pos++)
    {
        int i = order[pos];
        int st = 0;
        for (int j = 0; j < n; j++)
        {
            if (j == i || rank[j] > rank[i]) continue;
            bool explicit = false;
            for (int k = 0; k < self.systems[i].after_count; k++) if (self.systems[i].after[k] == j) explicit = true;
            if (explicit || conflicts(&self.systems[i], &self.systems[j]))
            {
                if (self.stage[j] + 1 > st) st = self.stage[j] + 1;
            }
        }
        self.stage[i] = st;
        if (st + 1 > self.stage_count) self.stage_count = st + 1;
    }
    return true;
}

fn void Scheduler.run(&self, Sim* s, bool reverse_within_stage)
{
    for (int st = 0; st < self.stage_count; st++)
    {
        for (int k = 0; k < self.count; k++)
        {
            int i = reverse_within_stage ? self.count - 1 - k : k;
            if (self.stage[i] == st) self.systems[i].run(s);
        }
    }
}

fn void Scheduler.print(&self)
{
    for (int st = 0; st < self.stage_count; st++)
    {
        io::printf("stage %d:", st);
        for (int i = 0; i < self.count; i++) if (self.stage[i] == st) io::printf(" %s", self.systems[i].name);
        io::printn();
    }
}

// ---------------- системы маленькой игры ----------------
fn void input_sys(Sim* s) { s.tick++; s.input = (s.tick * 7 + 3) % 11 - 5; }
fn void player_sys(Sim* s) { s.vel[0] = s.input; }
fn void ai_sys(Sim* s) { for (int i = 1; i < 4; i++) s.ai_target[i] = s.pos[0]; }
fn void steer_sys(Sim* s) { for (int i = 1; i < 4; i++) s.vel[i] = s.ai_target[i] > s.pos[i] ? 1 : -1; }
fn void move_sys(Sim* s) { for (int i = 0; i < 4; i++) s.pos[i] += s.vel[i]; }
fn void damage_sys(Sim* s) { for (int i = 1; i < 4; i++) if (s.pos[i] == s.pos[0]) s.hp[0] -= 1; }
fn void regen_sys(Sim* s) { for (int i = 1; i < 4; i++) if (s.hp[i] < 10) s.hp[i]++; }
fn void camera_sys(Sim* s) { s.camera += (s.pos[0] - s.camera) / 2; }
fn void render_sys(Sim* s)
{
    for (int i = 0; i < 4; i++) s.render_hash = s.render_hash * 31 + s.pos[i] - s.camera + s.hp[i];
}

fn bool sim_eq(Sim* a, Sim* b)
{
    for (int i = 0; i < 4; i++)
    {
        if (a.pos[i] != b.pos[i] || a.vel[i] != b.vel[i] || a.hp[i] != b.hp[i] || a.ai_target[i] != b.ai_target[i]) return false;
    }
    return a.input == b.input && a.tick == b.tick && a.camera == b.camera && a.render_hash == b.render_hash;
}

fn void main()
{
    Scheduler sc;
    int input  = sc.add("input",  0,            INPUT,  &input_sys);
    int player = sc.add("player", INPUT,        VEL,    &player_sys);
    int render = sc.add("render", POS | HP | CAMERA, RENDER, &render_sys);
    int ai     = sc.add("ai",     POS,          AI,     &ai_sys);
    int steer  = sc.add("steer",  AI | POS,     VEL,    &steer_sys);
    int move   = sc.add("move",   VEL,          POS,    &move_sys);
    int regen  = sc.add("regen",  0,            HP,     &regen_sys);
    int damage = sc.add("damage", POS,          HP,     &damage_sys);
    int camera = sc.add("camera", POS,          CAMERA, &camera_sys, { move });
    // render зарегистрирован рано, но должен идти после камеры и урона.
    sc.systems[render].after[sc.systems[render].after_count++] = camera;
    sc.systems[render].after[sc.systems[render].after_count++] = damage;

    assert(conflicts(&sc.systems[move], &sc.systems[ai]), "move writes POS, ai reads POS");
    assert(!conflicts(&sc.systems[ai], &sc.systems[regen]), "ai and regen touch different data");
    assert(conflicts(&sc.systems[player], &sc.systems[steer]), "both write VEL");
    assert(!conflicts(&sc.systems[input], &sc.systems[regen]));

    assert(sc.build(), "the graph has no cycles");
    sc.print();
    // Проверки плана.
    for (int i = 0; i < sc.count; i++)
    {
        for (int j = 0; j < sc.count; j++)
        {
            if (i != j && sc.stage[i] == sc.stage[j]) assert(!conflicts(&sc.systems[i], &sc.systems[j]), "conflicting systems share a stage");
        }
        for (int k = 0; k < sc.systems[i].after_count; k++) assert(sc.stage[sc.systems[i].after[k]] < sc.stage[i], "after-constraint violated");
    }
    assert(sc.stage[render] > sc.stage[camera] && sc.stage[render] > sc.stage[damage]);
    assert(sc.stage[input] == 0 && sc.stage[regen] == 0 && sc.stage[ai] == 0, "independent systems start at stage 0");

    Sim a = { .pos = { 0, 10, -10, 20 }, .hp = { 100, 5, 5, 5 } };
    Sim b = a;
    for (int t = 0; t < 100; t++)
    {
        sc.run(&a, false);
        sc.run(&b, true);
    }
    io::printfn("player pos=%d hp=%d camera=%d enemies=(%d,%d,%d) render_hash=%d",
                a.pos[0], a.hp[0], a.camera, a.pos[1], a.pos[2], a.pos[3], a.render_hash);
    assert(sim_eq(&a, &b), "order inside a stage must not matter");

    // Цикл: render после camera, а camera после render.
    sc.systems[camera].after[sc.systems[camera].after_count++] = render;
    assert(!sc.build(), "a cycle must be detected");
    io::printn("cycle detected");
    io::printn("scheduler OK");
}
