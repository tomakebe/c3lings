// =====================================================================
//  E0105 · Игровой цикл целиком
// =====================================================================
//
//  Сначала прочитайте engine/docs/01_game_loop.md (весь, особенно
//  разделы 7–8).
//
//  Соберём всё вместе в переиспользуемый объект GameLoop:
//
//    * время берётся из интерфейса Clock — в игре это монотонные часы
//      ОС, в тестах «фальшивые» часы со сценарием длительностей кадров;
//    * игра — это интерфейс Game с двумя методами: fixed_update(tick, dt)
//      (симуляция, фиксированный шаг) и render(alpha) (интерполяция);
//    * тело цикла — run_frame(): его можно вызывать из своего while или
//      из колбэка платформы (requestAnimationFrame, CADisplayLink);
//    * защита от спирали смерти: max_frame_us и max_steps (как в E0103,
//      отброшенное время считаем в dropped_us);
//    * пауза: симуляция стоит, рендер продолжается, alpha «заморожена»;
//    * масштаб времени задан ДРОБЬЮ scale_num/scale_den и применяется к
//      длительности кадра (а не к dt!). Чтобы не терять доли микросекунд
//      при делении, остаток от деления копится в scale_rem:
//          scaled = frame * num + scale_rem;
//          acc   += scaled / den;   scale_rem = scaled % den;
//      Так за любое число кадров игровое время == floor(real * num / den).
//
//  Подвох первого кадра: часы показывают «аптайм» (здесь 10^9 мкс).
//  Если last_us начать с нуля, первый кадр окажется длиной в 1000 секунд.
//  start() должен запомнить текущее время часов.
//
//  Порядок в run_frame:
//    1. frame = now - last_us; last_us = now; frames++;
//    2. обрезать frame до max_frame_us (лишнее -> dropped_us);
//    3. если paused — frame = 0;
//    4. масштабировать (с остатком) и добавить в acc_us;
//    5. не больше max_steps тиков: game.fixed_update(tick, dt_us); tick++;
//    6. если acc_us всё ещё >= dt_us — отбросить целые шаги (-> dropped_us);
//    7. game.render((double)acc_us / dt_us).
//
//  ЗАДАЧА: реализуйте GameLoop.start, GameLoop.set_time_scale и
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
    // TODO: запомнить текущее время часов, обнулить аккумулятор и остаток масштаба
}

fn void GameLoop.set_time_scale(&self, long num, long den)
{
    // TODO: сохранить дробь num/den, сбросить остаток
}

fn void GameLoop.run_frame(&self, Clock clock, Game game)
{
    // TODO: шаги 1–7 из шапки
    game.render(0.0);
}

// ----------------------------------------------------------------------
// Фальшивые часы: каждый вызов now_us() сдвигает время на следующий
// интервал из сценария (по кругу).

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
// Тестовая игра: тело летит на 1 единицу за тик, рендер интерполирует.

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
    long[] script = { 6_944 };          // 144 Гц
    FakeClock clock = { .t = 1_000_000_000, .script = script };
    TestGame game;
    GameLoop loop;
    loop.init(10_000, 250_000, 5);
    loop.start(&clock);

    // 1. Обычная игра: 144 кадра.
    for (int i = 0; i < 144; i++) loop.run_frame(&clock, &game);
    assert(loop.dropped_us == 0, "first frame must not be huge: call clock.now_us() in start()");
    assert(loop.tick == 144 * 6_944 / 10_000);
    assert(game.renders == 144 && game.updates == loop.tick);
    report("normal", &loop, &game);

    // 2. Пауза: рендер идёт, тики стоят, alpha заморожена.
    long ticks_before = loop.tick;
    double alpha_before = game.last_alpha;
    loop.paused = true;
    for (int i = 0; i < 30; i++) loop.run_frame(&clock, &game);
    assert(loop.tick == ticks_before, "paused game must not tick");
    assert(game.renders == 174, "render must continue while paused");
    assert(game.last_alpha == alpha_before, "alpha must be frozen during pause");
    loop.paused = false;
    report("paused", &loop, &game);

    // 3. Замедление в 3 раза: игровое время = floor(real / 3), без потерь.
    long sim_before = loop.tick * loop.dt_us + loop.acc_us;
    loop.set_time_scale(1, 3);
    for (int i = 0; i < 100; i++) loop.run_frame(&clock, &game);
    long sim_delta = loop.tick * loop.dt_us + loop.acc_us - sim_before;
    assert(sim_delta == 100 * 6_944 / 3, "time scale lost precision: %d", sim_delta);
    loop.set_time_scale(1, 1);
    report("slowmo1/3", &loop, &game);

    // 4. Брейкпойнт: следующий кадр длится 3 секунды.
    script[0] = 3_000_000;
    long ticks_bp = loop.tick;
    loop.run_frame(&clock, &game);     // этот кадр ещё короткий, но часы ушли на 3 с вперёд
    script[0] = 6_944;
    loop.run_frame(&clock, &game);     // а этот кадр длится 3 секунды
    assert(loop.tick - ticks_bp <= 2 * 5, "max_steps violated");
    assert(loop.dropped_us > 2_500_000, "a 3 s frame must be mostly dropped");
    report("breakpoint", &loop, &game);

    // 5. Снова нормально.
    for (int i = 0; i < 50; i++) loop.run_frame(&clock, &game);
    assert(game.updates == loop.tick);
    assert(math::abs(game.last_render - ((double)loop.tick - 1.0 + game.last_alpha)) < 1e-9);
    report("resumed", &loop, &game);
    io::printn("game loop OK");
}
