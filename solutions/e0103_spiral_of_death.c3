// =====================================================================
//  E0103 · The spiral of death
// =====================================================================
//
//  Read engine/docs/01_game_loop.md first (section 4).
//
//  If a single update tick costs more than DT of real time, the
//  accumulator loop falls into the "spiral of death": we fall behind ->
//  we need more ticks -> the frame gets longer -> we fall further behind.
//  The same happens after one giant frame (loading, a breakpoint, a
//  minimized window).
//
//  There is no real clock here: frame duration is computed from a COST
//  MODEL — a frame lasts RENDER_COST + steps * UPDATE_COST, where steps is
//  the number of ticks in that frame. This makes behavior reproducible
//  down to the microsecond.
//
//  The naive loop (naive_advance) is already written — run it and watch
//  the number of ticks per frame grow.
//
//  The protected loop applies two safeguards:
//    1. frame duration is clamped to max_frame_us; the clamped-off time
//       is added to dropped_us, and clamped_frames++;
//    2. at most max_steps ticks run per frame; if after that the
//       accumulator still holds >= dt, the extra WHOLE steps are discarded
//       (acc is left as acc % dt), the discarded time goes to dropped_us,
//       and limited_frames++.
//
//  The main invariant: time never disappears without a trace —
//      ticks * dt + acc + dropped == total real time.
//  Dropped time is the game slowing down relative to reality; it must be
//  counted so the profiler can say "budget exceeded".
//
//  TASK: implement ProtectedLoop.advance.
//
import std::io;

struct ProtectedLoop
{
    long dt_us;
    long max_frame_us;
    int  max_steps;
    long acc_us;
    long ticks;
    long dropped_us;
    int  clamped_frames;
    int  limited_frames;
}

// Returns the number of ticks executed.
fn int ProtectedLoop.advance(&self, long frame_us)
{
    if (frame_us > self.max_frame_us)
    {
        self.dropped_us += frame_us - self.max_frame_us;
        frame_us = self.max_frame_us;
        self.clamped_frames++;
    }
    self.acc_us += frame_us;
    int steps = 0;
    while (self.acc_us >= self.dt_us && steps < self.max_steps)
    {
        self.acc_us -= self.dt_us;
        self.ticks++;
        steps++;
    }
    if (self.acc_us >= self.dt_us)
    {
        long keep = self.acc_us % self.dt_us;
        self.dropped_us += self.acc_us - keep;
        self.acc_us = keep;
        self.limited_frames++;
    }
    return steps;
}

// Naive version — no safeguards.
fn int naive_advance(long* acc, long dt, long frame_us)
{
    *acc += frame_us;
    int steps = 0;
    while (*acc >= dt) { *acc -= dt; steps++; }
    return steps;
}

const long DT = 10_000;
const long RENDER_COST = 2_000;

fn void main()
{
    // --- 1. Naive loop with UPDATE_COST > DT ---
    long update_cost = 12_000;
    long acc = 0;
    long frame = DT;
    io::printf("naive steps:");
    int last_steps = 0;
    for (int i = 0; i < 14; i++)
    {
        int steps = naive_advance(&acc, DT, frame);
        io::printf(" %d", steps);
        frame = RENDER_COST + steps * update_cost;   // how long this frame took
        last_steps = steps;
    }
    io::printn();
    assert(last_steps >= 5, "the naive loop should be spiralling");

    // --- 2. Protected loop at the same cost ---
    ProtectedLoop p = { .dt_us = DT, .max_frame_us = 50_000, .max_steps = 3 };
    long real = 0;
    long worst_frame = 0;
    frame = DT;
    for (int i = 0; i < 200; i++)
    {
        int steps = p.advance(frame);
        real += frame;
        assert(steps <= p.max_steps, "too many steps: %d", steps);
        assert(p.acc_us >= 0 && p.acc_us < DT, "acc out of range: %d", p.acc_us);
        assert(p.ticks * DT + p.acc_us + p.dropped_us == real, "time leaked at frame %d", i);
        frame = RENDER_COST + steps * update_cost;
        if (frame > worst_frame) worst_frame = frame;
    }
    assert(worst_frame <= RENDER_COST + p.max_steps * update_cost);
    io::printfn("protected: ticks=%d dropped=%dus limited=%d clamped=%d worst_frame=%dus",
                p.ticks, p.dropped_us, p.limited_frames, p.clamped_frames, worst_frame);
    io::printfn("game time runs at %d%% of real time", p.ticks * DT * 100 / real);

    // --- 3. Breakpoint: a single 5-second frame, cheap update ---
    ProtectedLoop q = { .dt_us = DT, .max_frame_us = 100_000, .max_steps = 8 };
    long[] frames = { 16_000, 16_000, 5_000_000, 16_000, 16_000 };
    real = 0;
    io::printf("breakpoint steps:");
    foreach (f : frames)
    {
        int steps = q.advance(f);
        real += f;
        assert(q.ticks * DT + q.acc_us + q.dropped_us == real, "time leaked");
        io::printf(" %d", steps);
    }
    io::printn();
    assert(q.clamped_frames == 1 && q.limited_frames == 1);
    io::printfn("breakpoint: ticks=%d dropped=%dus", q.ticks, q.dropped_us);
    io::printn("spiral of death avoided");
}
