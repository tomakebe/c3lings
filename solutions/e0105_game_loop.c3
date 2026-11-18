// =====================================================================
//  E0105 · The complete game loop
// =====================================================================
//
//  Read engine/docs/01_game_loop.md first (all of it, especially
//  sections 7–8).
//
//  Let's put everything together into a reusable GameLoop object:
//
//    * time comes from a Clock interface — in the game it is the OS
//      monotonic clock, in tests a "fake" clock with a scripted sequence
//      of frame durations;
//    * the game is a Game interface with two methods: fixed_update(tick, dt)
//      (simulation, fixed step) and render(alpha) (interpolation);
//    * the loop body is run_frame(): it can be called from your own while
//      loop or from a platform callback (requestAnimationFrame, CADisplayLink);
//    * spiral-of-death protection: max_frame_us and max_steps (as in E0103,
//      dropped time is counted in dropped_us);
//    * pause: the simulation stops, rendering continues, alpha is "frozen";
//    * time scale is given as a FRACTION scale_num/scale_den and applied to
//      the frame duration (not to dt!). To avoid losing fractions of a
//      microsecond in the division, the remainder accumulates in scale_rem:
//          scaled = frame * num + scale_rem;
//          acc   += scaled / den;   scale_rem = scaled % den;
//      This way, over any number of frames, game time == floor(real * num / den).
//
//  The first-frame gotcha: the clock reports "uptime" (here 10^9 us).
//  If last_us starts at zero, the first frame will be 1000 seconds long.
//  start() must record the clock's current time.
//
//  Order of operations in run_frame:
//    1. frame = now - last_us; last_us = now; frames++;
//    2. clamp frame to max_frame_us (the excess -> dropped_us);
//    3. if paused — frame = 0;
//    4. scale (with remainder) and add to acc_us;
//    5. at most max_steps ticks: game.fixed_update(tick, dt_us); tick++;
//    6. if acc_us is still >= dt_us — discard whole steps (-> dropped_us);
//    7. game.render((double)acc_us / dt_us).
//
//  TASK: implement GameLoop.start, GameLoop.set_time_scale and
//  GameLoop.run_frame.
//
import std::io, std::math;

interface Clock
{
    fn long now_us();
}

interface Game
{
    fn void fixed_update(long tick, long dt_us);
    fn void render(double alpha);
}

struct GameLoop
{
    long dt_us;
    long max_frame_us;
    int  max_steps;

    long acc_us;
    long last_us;
    long tick;
    long frames;
    long dropped_us;
    long scale_num;
    long scale_den;
    long scale_rem;
    bool paused;
}

fn void GameLoop.init(&self, long dt_us, long max_frame_us, int max_steps)
{
    *self = { .dt_us = dt_us, .max_frame_us = max_frame_us, .max_steps = max_steps,
              .scale_num = 1, .scale_den = 1 };
}

fn void GameLoop.start(&self, Clock clock)
{
    self.last_us = clock.now_us();
    self.acc_us = 0;
    self.scale_rem = 0;
}

fn void GameLoop.set_time_scale(&self, long num, long den)
{
    self.scale_num = num;
    self.scale_den = den;
    self.scale_rem = 0;
}

fn void GameLoop.run_frame(&self, Clock clock, Game game)
{
    long now = clock.now_us();
    long frame = now - self.last_us;
    self.last_us = now;
    self.frames++;
    if (frame > self.max_frame_us)
    {
        self.dropped_us += frame - self.max_frame_us;
        frame = self.max_frame_us;
    }
    if (self.paused) frame = 0;
    long scaled = frame * self.scale_num + self.scale_rem;
    self.acc_us += scaled / self.scale_den;
    self.scale_rem = scaled % self.scale_den;

    int steps = 0;
    while (self.acc_us >= self.dt_us && steps < self.max_steps)
    {
        game.fixed_update(self.tick, self.dt_us);
        self.tick++;
        self.acc_us -= self.dt_us;
        steps++;
    }
    if (self.acc_us >= self.dt_us)
    {
        long keep = self.acc_us % self.dt_us;
        self.dropped_us += self.acc_us - keep;
        self.acc_us = keep;
    }
    game.render((double)self.acc_us / (double)self.dt_us);
}

// ----------------------------------------------------------------------
// Fake clock: every call to now_us() advances time by the next
// interval from the script (cyclically).

struct FakeClock (Clock)
{
    long t;
    long[] script;
    sz next;
}

fn long FakeClock.now_us(&self) @dynamic
{
    long r = self.t;
    self.t += self.script[self.next % self.script.len];
    self.next++;
    return r;
}

// ----------------------------------------------------------------------
// Test game: the body moves 1 unit per tick, rendering interpolates.

struct TestGame (Game)
{
    long expected_tick;
    long updates;
    long renders;
    double prev_x;
    double x;
    double last_alpha;
    double last_render;
}

fn void TestGame.fixed_update(&self, long tick, long dt_us) @dynamic
{
    assert(tick == self.expected_tick, "ticks must be consecutive");
    assert(dt_us == 10_000, "dt must never change (time scale applies to frames!)");
    self.expected_tick++;
    self.updates++;
    self.prev_x = self.x;
    self.x += 1.0;
}

fn void TestGame.render(&self, double alpha) @dynamic
{
    assert(alpha >= 0.0 && alpha < 1.0, "alpha out of range: %f", alpha);
    self.renders++;
    self.last_alpha = alpha;
    self.last_render = self.prev_x + (self.x - self.prev_x) * alpha;
}

fn void report(String phase, GameLoop* loop, TestGame* g)
{
    io::printfn("%-10s frames=%3d ticks=%4d acc=%5d dropped=%7d render_x=%.3f",
                phase, loop.frames, loop.tick, loop.acc_us, loop.dropped_us, g.last_render);
}

fn void main()
{
    long[] script = { 6_944 };          // 144 Hz
    FakeClock clock = { .t = 1_000_000_000, .script = script };
    TestGame game;
    GameLoop loop;
    loop.init(10_000, 250_000, 5);
    loop.start(&clock);

    // 1. Normal play: 144 frames.
    for (int i = 0; i < 144; i++) loop.run_frame(&clock, &game);
    assert(loop.dropped_us == 0, "first frame must not be huge: call clock.now_us() in start()");
    assert(loop.tick == 144 * 6_944 / 10_000);
    assert(game.renders == 144 && game.updates == loop.tick);
    report("normal", &loop, &game);

    // 2. Pause: rendering continues, ticks stop, alpha is frozen.
    long ticks_before = loop.tick;
    double alpha_before = game.last_alpha;
    loop.paused = true;
    for (int i = 0; i < 30; i++) loop.run_frame(&clock, &game);
    assert(loop.tick == ticks_before, "paused game must not tick");
    assert(game.renders == 174, "render must continue while paused");
    assert(game.last_alpha == alpha_before, "alpha must be frozen during pause");
    loop.paused = false;
    report("paused", &loop, &game);

    // 3. 3x slow motion: game time = floor(real / 3), nothing lost.
    long sim_before = loop.tick * loop.dt_us + loop.acc_us;
    loop.set_time_scale(1, 3);
    for (int i = 0; i < 100; i++) loop.run_frame(&clock, &game);
    long sim_delta = loop.tick * loop.dt_us + loop.acc_us - sim_before;
    assert(sim_delta == 100 * 6_944 / 3, "time scale lost precision: %d", sim_delta);
    loop.set_time_scale(1, 1);
    report("slowmo1/3", &loop, &game);

    // 4. Breakpoint: the next frame lasts 3 seconds.
    script[0] = 3_000_000;
    long ticks_bp = loop.tick;
    loop.run_frame(&clock, &game);     // this frame is still short, but the clock has jumped 3 s ahead
    script[0] = 6_944;
    loop.run_frame(&clock, &game);     // and this frame lasts 3 seconds
    assert(loop.tick - ticks_bp <= 2 * 5, "max_steps violated");
    assert(loop.dropped_us > 2_500_000, "a 3 s frame must be mostly dropped");
    report("breakpoint", &loop, &game);

    // 5. Back to normal.
    for (int i = 0; i < 50; i++) loop.run_frame(&clock, &game);
    assert(game.updates == loop.tick);
    assert(math::abs(game.last_render - ((double)loop.tick - 1.0 + game.last_alpha)) < 1e-9);
    report("resumed", &loop, &game);
    io::printn("game loop OK");
}
