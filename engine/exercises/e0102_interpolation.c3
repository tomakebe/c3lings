// =====================================================================
//  E0102 · Interpolating state for rendering
// =====================================================================
//
//  Read engine/docs/01_game_loop.md first (section 3).
//
//  After the `while (acc >= DT)` loop the accumulator holds a remainder
//  0 <= acc < DT: real time that has not been simulated yet.
//  If you simply draw the latest state, then with a 144 Hz monitor and a
//  100 Hz simulation the object will alternately stand still and jump — judder.
//
//  The fix: keep TWO states — previous and current — and draw
//
//      alpha  = acc / DT                    (0 <= alpha < 1)
//      render = prev + (curr - prev) * alpha
//
//  The price is one tick of latency: the image lags the simulation by
//  (1 - alpha) * DT. In exchange, motion is smooth.
//
//  An important subtlety is TELEPORTING. If an object is moved instantly but
//  prev is left untouched, interpolation will "drag" it across the whole map
//  over the next frames. A teleport must reset prev = curr.
//
//  Here the object moves at 100 units/s with a 10 ms step, i.e. exactly
//  1 unit per tick. So the correctly interpolated position at time T is
//  (T / DT) - 1 (one tick behind), and between consecutive 144 Hz frames
//  the object moves by 0.6944 units.
//
//  TASK: implement
//    * Body.step     — remember prev and advance x by vel * dt;
//    * Body.teleport — move the object without "dragging";
//    * Body.render_x — the interpolated position for a given alpha;
//    * compute_alpha — alpha from the accumulator and the step (in double!).
//
import std::io, std::math;

struct Body
{
    double prev_x;
    double x;
    double vel;     // units per second
}

fn void Body.step(&self, long dt_us)
{
    // TODO: save the previous state and integrate the position
    self.x += self.vel * (double)dt_us / 1_000_000.0;
}

fn void Body.teleport(&self, double to)
{
    // TODO: a teleport must not "drag" the object through interpolation
    self.x = to;
}

fn double Body.render_x(&self, double alpha)
{
    // TODO: interpolate between prev_x and x
    return self.x;
}

fn double compute_alpha(long acc_us, long dt_us)
{
    // TODO: fraction of the unsimulated step, 0 <= alpha < 1
    return 0;
}

const long DT = 10_000;      // 100 Hz
const long FRAME = 6_944;    // ~144 Hz

fn void main()
{
    Body b = { .vel = 100.0 };
    long acc = 0;
    long now = 0;
    long ticks = 0;
    double last_render = 0;
    bool have_last = false;
    double min_delta = 1e9;
    double max_delta = -1e9;

    for (int frame = 0; frame < 200; frame++)
    {
        now += FRAME;
        acc += FRAME;
        while (acc >= DT)
        {
            b.step(DT);
            acc -= DT;
            ticks++;
        }
        double alpha = compute_alpha(acc, DT);
        assert(alpha >= 0.0 && alpha < 1.0, "alpha out of [0,1): %f", alpha);
        if (ticks < 1) continue;

        double r = b.render_x(alpha);
        double expected = (double)now / (double)DT - 1.0;
        assert(math::abs(r - expected) < 1e-6, "frame %d: render %.4f, expected %.4f", frame, r, expected);
        if (have_last)
        {
            double d = r - last_render;
            if (d < min_delta) min_delta = d;
            if (d > max_delta) max_delta = d;
        }
        if (frame % 40 == 0) io::printfn("frame %3d ticks %3d alpha %.4f render_x %.4f", frame, ticks, alpha, r);
        last_render = r;
        have_last = true;
    }
    // Without interpolation the steps would be 0 or 1; with it, always 0.6944.
    assert(max_delta - min_delta < 1e-6, "motion is not smooth: deltas in [%.4f, %.4f]", min_delta, max_delta);
    io::printfn("smooth: every frame moves %.4f units", min_delta);

    // Teleport: no frame may show a point between the old and the new location.
    b.teleport(1000.0);
    for (int frame = 0; frame < 10; frame++)
    {
        acc += FRAME;
        while (acc >= DT) { b.step(DT); acc -= DT; ticks++; }
        double r = b.render_x(compute_alpha(acc, DT));
        assert(r >= 1000.0, "teleport smeared the object: render_x %.4f", r);
    }
    io::printfn("teleport: no smearing, x=%.4f", b.x);
    io::printn("interpolation OK");
}
