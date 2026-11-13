// =====================================================================
//  e1804 · Детерминированный lockstep с задержкой ввода
// =====================================================================
//
//  Самая старая сетевая модель (Doom, StarCraft, Age of Empires,
//  большинство RTS и файтингов): по сети передаётся ТОЛЬКО ВВОД, а
//  каждый участник симулирует всю игру сам. Если симуляция строго
//  детерминирована (глава 01: фиксированный шаг, целочисленная или
//  фиксированная точка, одинаковый порядок обработки), то при одинаковом
//  вводе у всех получается один и тот же мир. Трафик ничтожен и не
//  зависит от числа юнитов — 1500 лучников стоят столько же, сколько 1.
//
//  Цена: тик T можно симулировать, только когда известен ввод ВСЕХ
//  игроков на тик T. Чтобы не ждать пакеты каждый тик, вводят
//  ЗАДЕРЖКУ ВВОДА (input delay): нажатие в кадре F применяется в тике
//  F + DELAY. Пока идут DELAY тиков, пакет успевает долететь.
//
//      кадр F:  читаю свой ввод -> планирую на тик F+DELAY -> шлю всем
//               пытаюсь симулировать до тика F включительно:
//               while (tick <= F && есть ввод обоих на tick) step(tick++)
//               не дошёл до F -> «stall» (игра подвисает, ждём сеть)
//
//      DELAY = 0:  каждый тик ждём RTT/2 — постоянные подвисания
//      DELAY = 4:  при задержке сети <= 4 тиков — плавно, но ввод «вязкий»
//
//  (Rollback/GGPO решает это иначе: симулирует вперёд с УГАДАННЫМ
//  вводом соперника, а когда настоящий ввод приходит — откатывается и
//  пересчитывает. Подробнее — в главе.)
//
//  Обнаружение рассинхронизации: участники обмениваются контрольными
//  суммами состояния. Несовпадение = баг детерминизма, игра прерывается.
//
//  ЗАДАЧА: реализуйте Peer.try_advance и Sim.checksum.
//
import std::io;

const int MAX_TICKS = 128;
const int FRAMES = 100;

struct Unit { int x; int y; }      // фиксированная точка 24.8
struct Sim { Unit[2] u; }

fn void Sim.step(&self, int[2] input)
{
    for (int p = 0; p < 2; p++)
    {
        int in = input[p];
        if (in & 1) self.u[p].x += 3 * 256 / 2;
        if (in & 2) self.u[p].x -= 256;
        if (in & 4) self.u[p].y += 5 * 256 / 4;
        // взаимодействие: юниты отталкиваются, если близко
        int dx = self.u[0].x - self.u[1].x;
        if (dx < 256 && dx > -256) { self.u[0].x += 128; self.u[1].x -= 128; }
    }
}

// FNV-1a по всем полям (не по байтам структуры: паддинг может быть мусором).
fn uint Sim.checksum(&self)
{
    return 0; // TODO
}

struct Peer
{
    int id;
    Sim sim;
    int tick;                          // следующий тик для симуляции
    int[2][MAX_TICKS] inputs;          // inputs[tick][player]
    bool[2][MAX_TICKS] have;
    uint[MAX_TICKS] checksums;         // после симуляции тика
    int stalls;
}

// Симулировать тики, пока tick <= target и известен ввод обоих игроков.
// Если до target дойти не удалось — stalls++ (один раз за вызов).
fn void Peer.try_advance(&self, int target)
{
    // TODO
    (void)target;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

struct Lcg { uint state; }
fn uint Lcg.next(&self) { self.state = self.state * 1103515245 + 12345; return (self.state >> 16) & 0x7FFF; }

struct Msg { int from; int tick; int input; int arrive; bool used; }

fn int input_of(int player, int frame) => (frame * (player + 3) / 7 + player) % 8;

fn void run(int delay, uint seed)
{
    Peer[2] peers = { { .id = 0 }, { .id = 1 } };
    foreach (&p : peers)
    {
        for (int t = 0; t < delay; t++) p.have[t] = { true, true };   // первые тики — пустой ввод
    }
    Msg[256] net;
    Lcg rng = { seed };
    // симулируем кадры с запасом, чтобы догнать хвост
    for (int frame = 0; frame < FRAMES + 20; frame++)
    {
        foreach (&m : net)
        {
            if (!m.used || m.arrive != frame) continue;
            m.used = false;
            Peer* dst = &peers[1 - m.from];
            dst.inputs[m.tick][m.from] = m.input;
            dst.have[m.tick][m.from] = true;
        }
        foreach (&p : peers)
        {
            int t = frame + delay;
            if (frame < FRAMES && t < MAX_TICKS)
            {
                int in = input_of(p.id, frame);
                p.inputs[t][p.id] = in;
                p.have[t][p.id] = true;
                foreach (&m : net)
                {
                    if (m.used) continue;
                    *m = { p.id, t, in, frame + 1 + (int)(rng.next() % 3), true };
                    break;
                }
            }
            p.try_advance(frame < FRAMES ? frame : FRAMES - 1);
        }
    }
    assert(peers[0].tick == FRAMES && peers[1].tick == FRAMES, "оба должны досимулировать все тики");
    for (int t = 0; t < FRAMES; t++)
    {
        assert(peers[0].checksums[t] == peers[1].checksums[t], "DESYNC на тике %d", t);
    }
    io::printfn("delay=%d: stalls %d/%d, final checksum %08x, unit0=(%d,%d)", delay, peers[0].stalls, peers[1].stalls,
        peers[0].checksums[FRAMES - 1], peers[0].sim.u[0].x / 256, peers[0].sim.u[0].y / 256);
}

fn void main()
{
    Sim a;
    Sim b = { .u = { { 1, 0 }, { 0, 0 } } };
    assert(a.checksum() != b.checksum(), "контрольная сумма должна зависеть от состояния");
    run(0, 42);
    run(2, 42);
    run(4, 42);
}
