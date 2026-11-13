// =====================================================================
//  E0104 · Детерминированная симуляция
// =====================================================================
//
//  Сначала прочитайте engine/docs/01_game_loop.md (раздел 5).
//
//  Детерминизм: одинаковое начальное состояние + одинаковый ввод =>
//  одинаковое состояние на КАЖДОМ тике, на любой частоте кадров.
//  На этом держатся replays, lockstep-мультиплеер и воспроизведение багов.
//
//  Что для этого сделано в коде ниже (и что должны сделать вы):
//    * симуляция на целых числах: позиции в фиксированной точке 8.8
//      (1 единица = 256), направления — таблица, никакого sin/cos/float;
//    * шаг всегда один и тот же; время кадров — целые микросекунды;
//    * ввод записан с привязкой к НОМЕРУ ТИКА, а не к кадру: запись
//      { tick = 120, buttons = THRUST } значит «начиная с тика 120
//      зажат газ». Воспроизведение применяет ввод к тем же тикам;
//    * после каждого тика состояние хешируется (FNV-1a, 64 бита) —
//      так в RTS ищут рассинхронизацию: первый тик с разными хешами.
//
//  Мы прогоняем одну и ту же запись ввода при четырёх «частотах кадров»
//  (30, 60, 144 Гц и рваный ритм из ГПСЧ с фиксированным seed) — итоговые
//  хеши обязаны совпасть. Для контраста в конце показан float с
//  переменным dt: там результат зависит от частоты кадров.
//
//  ЗАДАЧА:
//    * InputPlayer.at   — кнопки для данного тика (записи отсортированы
//      по tick; используйте курсор, тики запрашиваются по возрастанию);
//    * hash_long        — подмешать 8 байт числа в хеш FNV-1a
//      (младший байт первым: h ^= byte; h *= FNV_PRIME);
//    * run              — цикл с аккумулятором: ровно TARGET_TICKS тиков,
//      на каждом тике: buttons = player.at(tick); world.step(buttons);
//      hash = world.hash(hash). Кадры берутся из frames по кругу.
//
import std::io;

const uint LEFT   = 1;
const uint RIGHT  = 2;
const uint THRUST = 4;
const uint FIRE   = 8;

const long DT_US = 16_667;
const long TARGET_TICKS = 600;
const int WORLD = 256 << 8;      // размер мира в единицах 8.8

const ulong FNV_OFFSET = 14695981039346656037UL;
const ulong FNV_PRIME  = 1099511628211UL;

// cos(i * 22.5 градусов) * 64, округлено
const int[16] COS64 = { 64, 59, 45, 24, 0, -24, -45, -59, -64, -59, -45, -24, 0, 24, 45, 59 };

fn int dir_x(int a) => COS64[a & 15];
fn int dir_y(int a) => COS64[(a + 12) & 15];   // sin(a) = cos(a - 90)

struct InputEvent { long tick; uint buttons; }

struct InputPlayer
{
    InputEvent[] events;
    usz cursor;
    uint current;
}

fn uint InputPlayer.at(&self, long tick)
{
    // TODO: продвиньте курсор по всем записям с tick <= запрошенного,
    //       запоминая их buttons в self.current; верните self.current.
    return 0;
}

struct Bullet { int x, y, vx, vy, ttl; }

struct World
{
    int x, y, vx, vy;
    int angle;
    int cooldown;
    Bullet[16] bullets;
    int shots;
}

fn int wrap(int v) => ((v % WORLD) + WORLD) % WORLD;

fn void World.step(&self, uint buttons)
{
    if (buttons & LEFT) self.angle = (self.angle + 15) & 15;
    if (buttons & RIGHT) self.angle = (self.angle + 1) & 15;
    if (buttons & THRUST)
    {
        self.vx += dir_x(self.angle);
        self.vy += dir_y(self.angle);
    }
    self.vx -= self.vx / 32;     // трение
    self.vy -= self.vy / 32;
    self.x = wrap(self.x + self.vx);
    self.y = wrap(self.y + self.vy);
    if (self.cooldown > 0) self.cooldown--;
    if (buttons & FIRE && self.cooldown == 0)
    {
        foreach (&b : self.bullets)
        {
            if (b.ttl > 0) continue;
            *b = { self.x, self.y, dir_x(self.angle) * 8, dir_y(self.angle) * 8, 90 };
            self.shots++;
            self.cooldown = 10;
            break;
        }
    }
    foreach (&b : self.bullets)
    {
        if (b.ttl == 0) continue;
        b.x = wrap(b.x + b.vx);
        b.y = wrap(b.y + b.vy);
        b.ttl--;
    }
}

fn ulong hash_long(ulong h, long v)
{
    // TODO: FNV-1a по 8 байтам числа, младший байт первым
    return h;
}

fn ulong World.hash(&self, ulong h)
{
    h = hash_long(h, self.x);
    h = hash_long(h, self.y);
    h = hash_long(h, self.vx);
    h = hash_long(h, self.vy);
    h = hash_long(h, self.angle);
    h = hash_long(h, self.cooldown);
    foreach (b : self.bullets)
    {
        h = hash_long(h, b.x);
        h = hash_long(h, b.y);
        h = hash_long(h, b.ttl);
    }
    return h;
}

struct RunResult { ulong hash; long ticks; int frames; World world; }

fn RunResult run(InputEvent[] log, long[] frames)
{
    World w = { .x = WORLD / 2, .y = WORLD / 2 };
    InputPlayer player = { .events = log };
    ulong h = FNV_OFFSET;
    long tick = 0;
    int frame_count = 0;
    // TODO: это наивный цикл «один тик на кадр». Замените его циклом с
    //       аккумулятором (DT_US), который делает ровно TARGET_TICKS тиков.
    while (tick < TARGET_TICKS)
    {
        frame_count++;
        uint buttons = player.at(tick);
        w.step(buttons);
        h = w.hash(h);
        tick++;
    }
    return { h, tick, frame_count, w };
}

// Для контраста: float и переменный dt. Высота после 1 с падения.
fn float float_fall(long frame_us)
{
    float y = 100;
    float v = 0;
    long t = 0;
    while (t < 1_000_000)
    {
        float dt = (float)frame_us / 1e6f;
        v -= 9.81f * dt;
        y += v * dt;
        t += frame_us;
    }
    return y;
}

fn void main()
{
    // Сначала проверим хеш на известном значении (FNV-1a от 8 нулевых байт).
    assert(hash_long(FNV_OFFSET, 0) == 0xa8c7f832281a39c5UL, "hash_long is wrong");

    InputEvent[] log = {
        { 0, THRUST }, { 30, THRUST | LEFT }, { 45, THRUST | FIRE },
        { 120, FIRE }, { 121, 0 }, { 200, RIGHT | FIRE }, { 260, THRUST | RIGHT },
        { 333, THRUST }, { 400, FIRE | LEFT }, { 401, FIRE }, { 402, FIRE | LEFT },
        { 500, 0 }, { 550, THRUST | FIRE | RIGHT },
    };

    long[] hz30 = { 33_334 };
    long[] hz60 = { 16_667 };
    long[] hz144 = { 6_944 };
    long[64] jitter;
    uint seed = 12345;
    foreach (&f : jitter)
    {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5;
        *f = 2_000 + (long)(seed % 60_000);
    }

    RunResult[4] r = { run(log, hz30), run(log, hz60), run(log, hz144), run(log, &jitter) };
    String[4] names = { "30Hz", "60Hz", "144Hz", "jitter" };
    for (int i = 0; i < 4; i++)
    {
        io::printfn("%-7s frames=%4d ticks=%d hash=%016x", names[i], r[i].frames, r[i].ticks, r[i].hash);
        assert(r[i].ticks == TARGET_TICKS);
        assert(r[i].hash == r[0].hash, "desync between %s and %s", names[0], names[i]);
    }
    io::printfn("final: pos=(%d,%d) angle=%d shots=%d", r[0].world.x >> 8, r[0].world.y >> 8, r[0].world.angle, r[0].world.shots);
    assert(r[0].world.shots > 5, "fire input was not applied");

    bool differs = float_fall(33_334) != float_fall(6_944);
    io::printfn("float + variable dt depends on frame rate: %s", differs);
    io::printn("deterministic OK");
}
