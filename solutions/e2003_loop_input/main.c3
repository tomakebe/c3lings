// =====================================================================
//  e2003 · Итоговый проект, шаг 3: цикл с фиксированным шагом и ввод
// =====================================================================
//
//  Добавились loop.c3 (глава 01) и input.c3 (глава 10).
//
//  Главный цикл движка в итоговой игре выглядит так:
//
//      while (running)
//      {
//          long frame_us = clock.measure();          // реальное время
//          int steps = loop.advance(frame_us);       // 0, 1 или несколько
//          for (int i = 0; i < steps; i++)
//          {
//              char bits = replaying ? rec.play(tick) : poll_devices();
//              rec.record(tick, bits);
//              game.update(bits);                     // фиксированный dt
//              tick++;
//          }
//          render(alpha = loop.alpha256());           // интерполяция
//      }
//
//  Здесь «реальное время» — не часы ОС, а заранее заданная (и
//  детерминированная) последовательность длительностей кадров, включая
//  подвисание на 300 мс. Так тест воспроизводим.
//
//  ЗАДАЧА: реализуйте FixedLoop.advance (loop.c3), InputState.pressed /
//  released, Recording.record и Recording.play (input.c3).
//
module mini::app;
import mini::core, mini::loop, mini::input, std::io;

// «Бот»: какие кнопки зажаты на тике.
fn char bot(int tick)
{
    char b = 0;
    if (tick % 40 < 15) b |= input::bit(LEFT);
    if (tick >= 30 && tick < 70) b |= input::bit(THRUST);
    if (tick % 9 < 3) b |= input::bit(FIRE);
    return b;
}

fn void main()
{
    // --- фиксированный шаг: 60 Гц, кадры с джиттером и одно подвисание
    FixedLoop lp = { .dt = 16_667, .max_frame = 100_000 };
    assert(lp.advance(10_000) == 0, "10 мс < dt: шагов нет");
    assert(lp.advance(10_000) == 1, "накопилось 20 мс: один шаг");
    assert(lp.alpha256() == 3333 * 256 / 16667);
    assert(lp.advance(300_000) == 6, "подвисание обрезается до 100 мс");
    assert(lp.clipped == 200_000);

    FixedLoop game_loop = { .dt = 16_667, .max_frame = 250_000 };
    Rng rng = { 1 };
    int frames = 0;
    int[8] histogram;      // сколько кадров дали 0, 1, 2... шагов
    long simulated = 0;
    while (simulated < 3_000_000)
    {
        long frame = (long)(14_000 + rng.range(0, 6000));    // 14..20 мс
        if (frames == 100) frame = 300_000;          // подвисание
        simulated += frame;
        int steps = game_loop.advance(frame);
        histogram[steps < 7 ? steps : 7]++;
        frames++;
    }
    io::printfn("frames=%d ticks=%d clipped=%dus alpha=%d", frames, game_loop.ticks, game_loop.clipped, game_loop.alpha256());
    io::printfn("steps per frame: 0:%d 1:%d 2:%d 7+:%d", histogram[0], histogram[1], histogram[2], histogram[7]);

    // --- фронты
    InputState in;
    in.update(input::bit(FIRE));
    assert(in.pressed(FIRE) && in.down(FIRE));
    in.update(input::bit(FIRE));
    assert(!in.pressed(FIRE) && in.down(FIRE), "удержание — не нажатие");
    in.update(0);
    assert(in.released(FIRE) && !in.released(LEFT));

    // --- запись и воспроизведение
    Recording rec;
    InputState live;
    int presses_live = 0;
    for (int tick = 0; tick < 120; tick++)
    {
        char bits = bot(tick);
        rec.record(tick, bits);
        live.update(bits);
        if (live.pressed(FIRE)) presses_live++;
    }
    rec.rewind();
    InputState replay;
    int presses_replay = 0;
    uint h = core::FNV_BASIS;
    for (int tick = 0; tick < 120; tick++)
    {
        char bits = rec.play(tick);
        assert(bits == bot(tick), "реплей расходится на тике %d", tick);
        replay.update(bits);
        if (replay.pressed(FIRE)) presses_replay++;
        h = core::fnv_int(h, bits);
    }
    assert(presses_live == presses_replay);
    io::printfn("recording: %d events for 120 ticks, fire presses=%d, checksum=%08x", rec.count, presses_replay, h);
}
