// =====================================================================
//  e2006 · Итоговый проект, шаг 6: игра
// =====================================================================
//
//  Все подсистемы на месте. Осталось самое приятное — правила игры
//  (game.c3). Движок уже умеет: фиксированный шаг, кадровую арену,
//  хендлы, ECS, ввод с записью, физику с broadphase, события,
//  ASCII-рендер и профайлер. main ниже — это «платформенный слой»:
//
//      for each frame (длительности кадров — детерминированный список):
//          steps = loop.advance(frame_us)
//          repeat steps:
//              bits = replay ? rec.play(tick) : bot(tick); rec.record(...)
//              game.update(bits)                      <- тик симуляции
//              arena.reset()
//          render(world) -> framebuffer
//
//  Игра запускается ДВАЖДЫ: первый раз ввод даёт «бот» и он
//  записывается; второй раз ввод воспроизводится из записи. Если
//  симуляция детерминирована, контрольные суммы мира и кадра совпадут
//  побитно — это главный автотест движка (и основа реплеев, lockstep
//  и rollback из главы 18).
//
//  ЗАДАЧА: в game.c3 реализуйте Game.split_rock, Game.on_collision и
//  переход к следующей волне в конце Game.update. Правила — в
//  doc-комментариях к функциям.
//
module mini::app;
import mini::core, mini::ecs, mini::loop, mini::input, mini::physics, mini::render, mini::profile, mini::game, std::io;

char[1 << 16] g_frame_mem @align(16);

const int TICKS = 1800;     // 30 секунд игры при 60 Гц

fn char bot(int tick)
{
    char b = input::bit(FIRE);
    int phase = (tick / 50) % 6;
    if (phase == 0 || phase == 3) b |= input::bit(LEFT);
    if (phase == 1) b |= input::bit(RIGHT);
    if (phase == 4 && tick % 3 == 0) b |= input::bit(THRUST);
    return b;
}

struct RunResult
{
    uint world;
    uint frame;
    int score;
    int lives;
    int wave;
    int shots;
    int destroyed;
    int entities;
    int frames;
    usz arena_peak;
}

fn RunResult run(Recording* rec, bool replay, Framebuffer* fb, Profiler* prof)
{
    World* w = mem::new(World);
    defer free(w);
    Arena arena;
    arena.init(&g_frame_mem);
    Game g;
    g.init(w, &arena, prof, 31337);
    FixedLoop lp = { .dt = 16_667, .max_frame = 250_000 };
    Rng clock = { 5 };       // «часы»: длительности кадров
    int frames = 0;
    int tick = 0;
    if (replay) rec.rewind();
    while (tick < TICKS)
    {
        long frame_us = (long)(12_000 + clock.range(0, 10_000));
        if (frames % 500 == 499) frame_us = 120_000;     // редкие подвисания
        int steps = lp.advance(frame_us);
        for (int s = 0; s < steps && tick < TICKS; s++)
        {
            char bits;
            if (replay)
            {
                bits = rec.play(tick);
            }
            else
            {
                bits = bot(tick);
                rec.record(tick, bits);
            }
            profile::@zone(prof, "tick")
            {
                g.update(bits);
            };
            arena.reset();
            tick++;
        }
        profile::@zone(prof, "render")
        {
            fb.clear();
            prof.add_work(render::draw_world(fb, w));
        };
        frames++;
    }
    return {
        .world = w.checksum(), .frame = fb.checksum(), .score = g.score, .lives = g.lives,
        .wave = g.wave, .shots = g.shots, .destroyed = g.rocks_destroyed,
        .entities = (int)w.pool.live, .frames = frames, .arena_peak = arena.peak,
    };
}

fn void main()
{
    Recording* rec = mem::new(Recording);
    defer free(rec);
    Framebuffer fb1;
    Framebuffer fb2;
    Profiler prof1;
    Profiler prof2;

    RunResult live = run(rec, false, &fb1, &prof1);
    RunResult again = run(rec, true, &fb2, &prof2);
    assert(live.world == again.world && live.frame == again.frame, "реплей разошёлся с живой игрой!");
    assert(live.destroyed > 0, "ни одного сбитого астероида — правила не работают");
    assert(live.wave >= 2, "волна должна смениться, когда астероиды кончились");

    io::printfn("frames=%d ticks=%d input events recorded=%d", live.frames, TICKS, rec.count);
    io::printfn("score=%d lives=%d wave=%d shots=%d rocks destroyed=%d entities=%d",
        live.score, live.lives, live.wave, live.shots, live.destroyed, live.entities);
    io::printfn("frame arena peak=%d bytes", live.arena_peak);
    fb1.print();
    io::printfn("world checksum=%08x frame checksum=%08x (replay: identical)", live.world, live.frame);
    prof1.report();
}
