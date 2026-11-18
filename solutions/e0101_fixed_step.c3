// =====================================================================
//  E0101 · Fixed timestep and the accumulator
// =====================================================================
//
//  Read engine/docs/01_game_loop.md first (sections 1–2).
//
//  The simulation advances in steps of one fixed length DT, while real
//  frame time is added to an accumulator and "paid out" in whole steps:
//
//      acc += frame_time;
//      while (acc >= DT) { update(DT); acc -= DT; }
//
//  We store time in INTEGER microseconds (`long`), not in double
//  seconds: that way the sum of frame times is exact and the tick count
//  doesn't "drift" because of rounding errors (see section 2.4 of the chapter).
//
//  To keep the test deterministic there is no real clock here: frame
//  durations come from an array — a "fake clock".
//
//  Invariants of a correct accumulator (main checks them):
//    * after advance(), always 0 <= acc < DT;
//    * over the whole run exactly total_time / DT ticks are executed
//      (integer division), and acc == total_time % DT — time is neither
//      lost nor created;
//    * a single frame may contain 0, 1 or several ticks.
//
//  TASK: implement FixedStepper.advance: add the frame duration to the
//  accumulator, run as many steps as fit (for each step increment
//  self.ticks and call self.on_tick), and return the number of steps
//  executed in this frame.
//
import std::io;

alias TickFn = fn void(long tick);

struct FixedStepper
{
    long dt_us;      // simulation step length
    long acc_us;     // not-yet-simulated remainder of real time
    long ticks;      // total number of steps executed
    TickFn on_tick;  // the game's "update"
}

fn int FixedStepper.advance(&self, long frame_us)
{
    self.acc_us += frame_us;
    int steps = 0;
    while (self.acc_us >= self.dt_us)
    {
        self.on_tick(self.ticks);
        self.ticks++;
        self.acc_us -= self.dt_us;
        steps++;
    }
    return steps;
}

long g_last_tick = -1;
int g_calls = 0;

fn void count_tick(long tick)
{
    // Ticks must be strictly consecutive: 0, 1, 2, ...
    assert(tick == g_last_tick + 1, "tick %d after %d", tick, g_last_tick);
    g_last_tick = tick;
    g_calls++;
}

fn void run_schedule(String name, long dt_us, long[] frames)
{
    g_last_tick = -1;
    g_calls = 0;
    FixedStepper s = { .dt_us = dt_us, .on_tick = &count_tick };
    long total = 0;
    int[8] hist;   // how many frames had 0,1,2,... ticks
    foreach (f : frames)
    {
        int steps = s.advance(f);
        total += f;
        assert(s.acc_us >= 0 && s.acc_us < dt_us, "accumulator out of range: %d", s.acc_us);
        assert(s.ticks == total / dt_us, "ticks %d, expected %d", s.ticks, total / dt_us);
        assert(s.acc_us == total % dt_us, "time lost or created");
        hist[steps < 7 ? steps : 7]++;
    }
    assert(g_calls == s.ticks, "on_tick must be called once per tick");
    io::printf("%-12s frames=%3d ticks=%3d acc=%5d  hist:", name, frames.len, s.ticks, s.acc_us);
    for (int i = 0; i < 7; i++) io::printf(" %d:%d", i, hist[i]);
    io::printn();
}

fn void main()
{
    const long DT = 16_667;   // ~60 Hz

    // 144 Hz monitor: frames of ~6944 us -> sometimes 0, sometimes 1 tick.
    long[100] fast;
    foreach (&f : fast) *f = 6_944;
    run_schedule("144Hz", DT, &fast);

    // 30 Hz: 2 ticks per frame.
    long[50] slow;
    foreach (&f : slow) *f = 33_334;
    run_schedule("30Hz", DT, &slow);

    // Ragged rhythm: a 100 ms hitch followed by a burst of short frames.
    long[] jitter = { 16_000, 17_500, 100_000, 1_000, 1_000, 1_000, 16_667, 33_000, 5_000, 12_000 };
    run_schedule("jitter", DT, jitter);

    // Hitting the step exactly: every frame = 1 tick, acc is always 0.
    long[60] exact;
    foreach (&f : exact) *f = DT;
    run_schedule("exact", DT, &exact);

    io::printn("fixed step OK");
}
