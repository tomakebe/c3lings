// =====================================================================
//  e0703 · Loading states, dependencies and an I/O budget
// =====================================================================
//
//  Read engine/docs/07_resources.md first (sections "Loading
//  states" and "Asynchronous loading").
//
//  Loading an asset is not an instant call but a process spread over frames:
//
//      UNLOADED --request--> QUEUED --IO slot--> LOADING --IO done--+
//                                                                    |
//                         FAILED <--file missing--------------------+
//                           ^                                        |
//                           +--dep failed-- WAITING_DEPS <-----------+
//                                                |
//                                   all deps LOADED
//                                                v
//                                             LOADED
//
//  * At most max_in_flight reads run at once: a disk (and
//    especially optical/network storage) does not like a hundred parallel requests.
//  * An asset becomes LOADED only once ALL its dependencies are loaded
//    (a material without a shader is useless). The asset's own bytes may
//    arrive earlier — then it waits in WAITING_DEPS.
//  * Failure propagates upward: if a texture is not found, the material
//    that depends on it is FAILED too. (Many engines instead
//    substitute a "placeholder" — a pink-and-black texture; see the chapter.)
//
//  Here "asynchrony" is modeled with ticks: each asset has an
//  io_cost — how many ticks its read takes. It is the same logic as in
//  real streaming, only without threads, and therefore deterministic.
//
//  TASK: implement Loader.request and Loader.tick (TODO below).
//    request(i): if the asset is not UNLOADED — do nothing (a repeated
//      request must not queue it a second time). Otherwise FIRST
//      recursively request the dependencies, THEN move the asset to QUEUED and
//      append it to the queue (dependencies start reading earlier).
//    tick() — three phases, strictly in this order:
//      1. All LOADING (in index order): remaining--; at 0 release the
//         IO slot (in_flight--) and move to FAILED (if missing) or
//         to WAITING_DEPS.
//      2. Dependency resolution: repeat passes over all WAITING_DEPS
//         while anything changes: if any dependency is FAILED -> FAILED;
//         if all are LOADED -> LOADED.
//      3. Start reads: while in_flight < max_in_flight and the queue is not empty,
//         take an asset from the FRONT of the queue -> LOADING, remaining = io_cost,
//         in_flight++, io_starts++.
//
import std::io;

enum LoadState : char
{
    UNLOADED,
    QUEUED,
    LOADING,
    WAITING_DEPS,
    LOADED,
    FAILED,
}

const String STATE_CHARS = ".QLWOF";   // UNLOADED QUEUED LOADING WAITING LOADED(O) FAILED

struct Asset
{
    String name;
    int io_cost;
    bool missing;          // the file is not on disk
    int[] deps;            // dependency indices
    LoadState state;
    int remaining;
}

const int MAX_QUEUE = 32;

struct Loader
{
    Asset[] assets;
    int max_in_flight;
    int in_flight;
    int peak_in_flight;
    int io_starts;
    int[MAX_QUEUE] queue;
    int q_head;
    int q_tail;
}

fn void Loader.push(&self, int i) @inline
{
    assert(self.q_tail < MAX_QUEUE);
    self.queue[self.q_tail++] = i;
}

fn void Loader.request(&self, int i)
{
    // TODO: if the asset is no longer UNLOADED — return; otherwise request the dependencies
    //       (recursively), then state = QUEUED and self.push(i).
    self.assets[i].state = QUEUED;
}

fn void Loader.tick(&self)
{
    // TODO: phase 1 — advance LOADING, phase 2 — resolve WAITING_DEPS
    //       to a fixed point, phase 3 — start new reads from the queue.
    //       Details are in the file header.
}

// ---------------------------------------------------------------------
// The checking code below does not need to be changed.
// ---------------------------------------------------------------------

fn bool Loader.busy(&self)
{
    foreach (a : self.assets)
    {
        if (a.state == QUEUED || a.state == LOADING || a.state == WAITING_DEPS) return true;
    }
    return false;
}

fn void Loader.check_invariants(&self)
{
    assert(self.in_flight <= self.max_in_flight, "IO budget exceeded");
    if (self.in_flight > self.peak_in_flight) self.peak_in_flight = self.in_flight;
    int loading = 0;
    foreach (a : self.assets)
    {
        if (a.state == LOADING) loading++;
        if (a.state == LOADED)
        {
            foreach (d : a.deps)
            {
                assert(self.assets[d].state == LOADED,
                       "%s is LOADED before its dependency %s", a.name, self.assets[d].name);
            }
        }
    }
    assert(loading == self.in_flight, "in_flight (%d) != number of LOADING assets (%d)",
           self.in_flight, loading);
}

fn void Loader.print(&self, int tick)
{
    io::printf("tick %2d:", tick);
    foreach (a : self.assets) io::printf(" %c", STATE_CHARS[a.state.ordinal]);
    io::printfn("   in_flight=%d", self.in_flight);
}

enum Id : int
{
    VS, FS, PROG, ALBEDO, NORMAL, HERO_MAT, MISSING_TEX, BROKEN_MAT, UNUSED
}

fn void main()
{
    Asset[*] assets = {
        [Id.VS.ordinal]          = { .name = "hero.vs",     .io_cost = 1 },
        [Id.FS.ordinal]          = { .name = "hero.fs",     .io_cost = 1 },
        [Id.PROG.ordinal]        = { .name = "hero.prog",   .io_cost = 1, .deps = { 0, 1 } },
        [Id.ALBEDO.ordinal]      = { .name = "albedo.tex",  .io_cost = 4 },
        [Id.NORMAL.ordinal]      = { .name = "normal.tex",  .io_cost = 3 },
        [Id.HERO_MAT.ordinal]    = { .name = "hero.mat",    .io_cost = 1, .deps = { 2, 3, 4 } },
        [Id.MISSING_TEX.ordinal] = { .name = "missing.tex", .io_cost = 2, .missing = true },
        [Id.BROKEN_MAT.ordinal]  = { .name = "broken.mat",  .io_cost = 1, .deps = { 2, 6 } },
        [Id.UNUSED.ordinal]      = { .name = "unused.tex",  .io_cost = 5 },
    };
    Loader ld = { .assets = &assets, .max_in_flight = 2 };

    io::printn("legend: . unloaded, Q queued, L loading, W waiting deps, O loaded, F failed");
    io::printf("        ");
    foreach (a : assets) io::printf(" %c", a.name[0]);
    io::printn();

    ld.request(Id.HERO_MAT.ordinal);
    ld.request(Id.BROKEN_MAT.ordinal);
    ld.request(Id.HERO_MAT.ordinal);        // repeated request — no effect
    assert(ld.q_tail == 8, "queue must contain 8 unique assets, got %d", ld.q_tail);
    assert(ld.queue[0] == Id.VS.ordinal && ld.queue[2] == Id.PROG.ordinal,
           "dependencies must be queued before the asset that needs them");
    assert(assets[Id.UNUSED.ordinal].state == UNLOADED);

    int tick = 0;
    int hero_ready_tick = -1;
    ld.print(tick);
    while (ld.busy())
    {
        tick++;
        assert(tick < 50, "loader does not make progress");
        ld.tick();
        ld.check_invariants();
        ld.print(tick);
        if (hero_ready_tick < 0 && assets[Id.HERO_MAT.ordinal].state == LOADED) hero_ready_tick = tick;
    }

    assert(assets[Id.HERO_MAT.ordinal].state == LOADED);
    assert(assets[Id.PROG.ordinal].state == LOADED);
    assert(assets[Id.MISSING_TEX.ordinal].state == FAILED);
    assert(assets[Id.BROKEN_MAT.ordinal].state == FAILED, "failure must propagate to dependents");
    assert(assets[Id.UNUSED.ordinal].state == UNLOADED, "nobody requested unused.tex");
    assert(ld.io_starts == 8, "each asset must be read exactly once");
    assert(ld.peak_in_flight == 2, "IO budget should be fully used");
    io::printfn("hero.mat ready at tick %d, total ticks %d, io_starts=%d",
                hero_ready_tick, tick, ld.io_starts);
}
