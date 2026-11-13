// ---------------------------------------------------------------------
//  mini::profile — инструментирующий профайлер с зонами (глава 15).
//
//      @zone(&prof, "physics") { ... };
//
//  Зона — begin при входе, end при выходе (через defer — даже при раннем
//  return). Профайлер хранит дерево вызовов в виде «плоских» зон с
//  глубиной первого входа. Время здесь мы НЕ меряем (вывод должен быть
//  детерминированным): вместо этого считаем вызовы и «единицы работы»
//  (проверенные пары, нарисованные спрайты), которые зона сама сообщает
//  через add_work. В настоящем движке рядом стояло бы time::now().
// ---------------------------------------------------------------------
module mini::profile;
import std::io;

const int MAX_ZONES = 16;
const int MAX_DEPTH = 8;

struct Zone
{
    String name;
    int depth;      // глубина вложенности (при первом входе)
    int calls;
    long work;
}

struct Profiler
{
    Zone[MAX_ZONES] zones;
    int count;
    int[MAX_DEPTH] stack;    // индексы открытых зон
    int depth;
}

fn int Profiler.find_or_add(&self, String name)
{
    for (int i = 0; i < self.count; i++) if (self.zones[i].name == name) return i;
    assert(self.count < MAX_ZONES);
    self.zones[self.count] = { .name = name, .depth = self.depth };
    return self.count++;
}

fn void Profiler.begin(&self, String name)
{
    assert(self.depth < MAX_DEPTH, "слишком глубокая вложенность зон");
    int z = self.find_or_add(name);
    self.zones[z].calls++;
    self.stack[self.depth++] = z;
}

fn void Profiler.end(&self)
{
    assert(self.depth > 0, "end без begin");
    self.depth--;
}

<* Добавить работу в САМУЮ ВНУТРЕННЮЮ открытую зону. *>
fn void Profiler.add_work(&self, long units)
{
    if (self.depth == 0) return;
    self.zones[self.stack[self.depth - 1]].work += units;
}

macro @zone(Profiler* p, String name; @body())
{
    p.begin(name);
    defer p.end();
    @body();
}

fn void Profiler.report(&self)
{
    io::printn("zone                    calls      work");
    for (int i = 0; i < self.count; i++)
    {
        Zone z = self.zones[i];
        for (int d = 0; d < z.depth; d++) io::printf("  ");
        io::printf("%s", z.name);
        for (usz pad = z.name.len + 2 * (usz)z.depth; pad < 22; pad++) io::printf(" ");
        io::printfn("%7d %9d", z.calls, z.work);
    }
}
