// =====================================================================
//  E0104 · Deterministic simulation
// =====================================================================
//
//  Read engine/docs/01_game_loop.md first (section 5).
//
//  Determinism: same initial state + same input => same state on EVERY
//  tick, at any frame rate. Replays, lockstep multiplayer and bug
//  reproduction all rely on this.
//
//  What the code below does to achieve this (and what you must do):
//    * the simulation uses integers: positions are 8.8 fixed point
//      (1 unit = 256), directions come from a table, no sin/cos/float;
//    * the step is always the same; frame times are integer microseconds;
//    * input is recorded against the TICK NUMBER, not the frame: the record
//      { tick = 120, buttons = THRUST } means "throttle held starting at
//      tick 120". Playback applies the input on the same ticks;
//    * after every tick the state is hashed (FNV-1a, 64 bits) — this is
//      how RTS games hunt desyncs: the first tick with differing hashes.
//
//  We replay the same input recording at four "frame rates" (30, 60,
//  144 Hz, and a ragged rhythm from a PRNG with a fixed seed) — the final
//  hashes must match. For contrast, the end shows float with a variable
//  dt: there the result depends on the frame rate.
//
//  TASK:
//    * InputPlayer.at   — the buttons for a given tick (records are sorted
//      by tick; use a cursor, ticks are queried in increasing order);
//    * hash_long        — mix the 8 bytes of a number into an FNV-1a hash
//      (low byte first: h ^= byte; h *= FNV_PRIME);
//    * run              — an accumulator loop: exactly TARGET_TICKS ticks,
//      on each tick: buttons = player.at(tick); world.step(buttons);
//      hash = world.hash(hash). Frames are taken from frames cyclically.
//
import std::io;

const uint LEFT   = 1;
const uint RIGHT  = 2;
const uint THRUST = 4;
const uint FIRE   = 8;

const long DT_US = 16_667;
const long TARGET_TICKS = 600;
const int WORLD = 256 << 8;      // world size in 8.8 units

const ulong FNV_OFFSET = 14695981039346656037UL;
const ulong FNV_PRIME  = 1099511628211UL;

// cos(i * 22.5 degrees) * 64, rounded
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
    // TODO: advance the cursor over all records with tick <= the requested one,
    //       storing their buttons in self.current; return self.current.
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
    self.vx -= self.vx / 32;     // friction
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
    // TODO: FNV-1a over the 8 bytes of the number, low byte first
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
    // TODO: this is a naive "one tick per frame" loop. Replace it with an
    //       accumulator loop (DT_US) that runs exactly TARGET_TICKS ticks.
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

// For contrast: float and a variable dt. Height after 1 s of falling.
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
    // First check the hash against a known value (FNV-1a of 8 zero bytes).
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
