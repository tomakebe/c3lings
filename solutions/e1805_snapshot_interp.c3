// =====================================================================
//  e1805 · Интерполяция снапшотов
// =====================================================================
//
//  Сервер шлёт снапшоты, скажем, 20 раз в секунду (раз в 50 мс), а
//  клиент рисует 60–144 кадра в секунду. Рисовать последний полученный
//  снапшот — значит, объекты дёргаются ступеньками, да ещё и с неровным
//  шагом: пакеты приходят с джиттером, иногда теряются, иногда
//  переставляются.
//
//  Решение (Valve Source, Quake 3 и почти все шутеры): клиент рисует
//  мир НЕМНОГО В ПРОШЛОМ — на interp_delay назад (обычно 2–3 интервала
//  снапшотов) — и интерполирует между двумя снапшотами, которые
//  окружают это время:
//
//    время сервера:  100      150      200      250      300
//    буфер:          [s100]   [s150]   [s200]   (s250 ещё летит)
//                                 ^ render_time = now - delay = 170
//    x = lerp(s150.x, s200.x, (170 - 150) / (200 - 150))
//
//  Если один снапшот потерялся, интерполируем между соседями через
//  него — потеря невидима. Если render_time обогнал самый свежий
//  снапшот (задержка слишком мала или долгая потеря) — буфер «голодает»:
//  остаётся держать последнее значение (или экстраполировать, рискуя
//  ошибиться). Цена метода — задержка: вы видите других игроков на
//  delay + ping/2 в прошлом (отсюда необходимость лаг-компенсации
//  попаданий на сервере, см. главу).
//
//  ЗАДАЧА: реализуйте SnapBuffer.insert (держать снапшоты
//  отсортированными по времени; дубликаты игнорировать; при
//  переполнении выбрасывать самый старый; снапшот старее самого
//  старого в полном буфере — игнорировать) и SnapBuffer.sample.
//
import std::io;

const int CAP = 6;

struct Snap { int time; int x; }    // время в мс, x в фиксированной точке (1/100)

struct SnapBuffer
{
    Snap[CAP] s;
    int count;
}

fn void SnapBuffer.insert(&self, Snap snap)
{
    int pos = 0;
    while (pos < self.count && self.s[pos].time < snap.time) pos++;
    if (pos < self.count && self.s[pos].time == snap.time) return;   // дубликат
    if (self.count == CAP)
    {
        if (pos == 0) return;             // старее всех в полном буфере
        // выбросить самый старый
        for (int i = 1; i < self.count; i++) self.s[i - 1] = self.s[i];
        self.count--;
        pos--;
    }
    for (int i = self.count; i > pos; i--) self.s[i] = self.s[i - 1];
    self.s[pos] = snap;
    self.count++;
}

// Значение x в момент t. Возвращает:
//   0 — интерполировано (или t точно равно времени снапшота),
//   1 — буфер «голодает»: t позже самого свежего, взяли самый свежий x,
//  -1 — данных нет (буфер пуст или t раньше самого старого), x не трогать.
fn int SnapBuffer.sample(&self, int t, int* x)
{
    if (self.count == 0 || t < self.s[0].time) return -1;
    if (t >= self.s[self.count - 1].time)
    {
        *x = self.s[self.count - 1].x;
        return t == self.s[self.count - 1].time ? 0 : 1;
    }
    for (int i = 0; i + 1 < self.count; i++)
    {
        Snap a = self.s[i];
        Snap b = self.s[i + 1];
        if (t >= a.time && t < b.time)
        {
            *x = a.x + (b.x - a.x) * (t - a.time) / (b.time - a.time);
            return 0;
        }
    }
    unreachable();
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

struct Lcg { uint state; }
fn uint Lcg.next(&self) { self.state = self.state * 1103515245 + 12345; return (self.state >> 16) & 0x7FFF; }

// Положение объекта на сервере: едет вправо и разворачивается.
fn int server_x(int t) => t < 600 ? t * 2 : 1200 - (t - 600) * 3;

struct Flight { Snap s; int arrive; bool used; }

fn void run(int delay)
{
    SnapBuffer buf;
    Flight[32] net;
    Lcg rng = { 99 };
    int starved = 0;
    int max_err = 0;
    int last_x = 0;
    for (int now = 0; now <= 1000; now += 10)    // кадры клиента каждые 10 мс
    {
        if (now % 50 == 0 && rng.next() % 100 >= 15)   // снапшот, 15% потерь
        {
            foreach (&f : net)
            {
                if (f.used) continue;
                *f = { { now, server_x(now) }, now + 30 + (int)(rng.next() % 50), true };   // 30..79 мс
                break;
            }
        }
        foreach (&f : net)
        {
            if (f.used && f.arrive <= now) { f.used = false; buf.insert(f.s); }
        }
        int x;
        int r = buf.sample(now - delay, &x);
        if (r < 0) continue;
        if (r == 1) starved++;
        int err = x - server_x(now - delay);
        if (err < 0) err = -err;
        if (err > max_err) max_err = err;
        last_x = x;
    }
    io::printfn("delay=%3d ms: starved frames=%2d, max error=%d, last x=%d", delay, starved, max_err, last_x);
}

fn void main()
{
    SnapBuffer b;
    b.insert({ 100, 10 });
    b.insert({ 300, 30 });
    b.insert({ 200, 20 });      // пришёл не по порядку
    b.insert({ 200, 99 });      // дубликат
    assert(b.count == 3 && b.s[1].time == 200 && b.s[1].x == 20, "сортировка и дубликаты");
    int x;
    assert(b.sample(50, &x) == -1);
    assert(b.sample(150, &x) == 0 && x == 15);
    assert(b.sample(275, &x) == 0 && x == 27);
    assert(b.sample(300, &x) == 0 && x == 30);
    assert(b.sample(400, &x) == 1 && x == 30, "голодание: держим последний");
    for (int t = 400; t <= 700; t += 100) b.insert({ t, t / 10 });
    assert(b.count == CAP && b.s[0].time == 200, "переполнение выбрасывает самый старый");
    b.insert({ 150, 0 });
    assert(b.s[0].time == 200, "слишком старый снапшот игнорируется");
    io::printn("buffer: ok");

    run(20);
    run(60);
    run(120);
    run(180);
}
