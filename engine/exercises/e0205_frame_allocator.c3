// =====================================================================
//  E0205 · Двухбуферный кадровый аллокатор
// =====================================================================
//
//  Сначала прочитайте engine/docs/02_memory.md (разделы 7–8).
//
//  Данные кадра (списки видимых объектов, команды рендера, временные
//  строки) выделяются линейно и освобождаются все сразу. Но при
//  конвейере «игровой поток -> поток рендера» рендер читает данные
//  кадра N, пока игра уже готовит кадр N+1. Значит, данные кадра должны
//  прожить ДВА кадра. Решение — две арены, меняющиеся ролями:
//
//      кадр:      N              N+1              N+2
//      арена 0:  [игра пишет N] [рендер читает N] [сброс; игра пишет N+2]
//      арена 1:  [рендер N-1]   [сброс; пишет N+1] [рендер читает N+1]
//
//  begin_frame():
//    * переключает текущую арену (current ^= 1);
//    * в отладке ЗАЛИВАЕТ использованную часть этой арены байтом 0xCD
//      (как отладочная куча MSVC): если кто-то сохранил указатель на
//      данные позапрошлого кадра, он прочитает 0xCDCDCDCD, а не
//      правдоподобный мусор;
//    * обнуляет offset и увеличивает frame.
//
//  Бюджет: каждой арене разрешено не больше budget байт за кадр (даже
//  если буфер больше). Превышение -> null и over_budget++. Пик
//  использования за кадр — в peak.
//
//  Игровой и рендер-поток здесь смоделированы последовательно в одном
//  потоке: game_frame() пишет пакеты кадра, render_frame() читает пакеты
//  ПРЕДЫДУЩЕГО кадра.
//
//  ЗАДАЧА: реализуйте FrameAllocator.begin_frame и FrameAllocator.alloc.
//
import std::io;

fn usz align_up(usz x, usz a) => (x + a - 1) & ~(a - 1);

const char POISON = 0xCD;

struct FrameArena
{
    char[] buf;
    usz offset;
}

struct FrameAllocator
{
    FrameArena[2] arenas;
    int current;
    ulong frame;
    usz budget;
    usz peak;
    usz over_budget;
}

fn void FrameAllocator.init(&self, char[] a, char[] b, usz budget)
{
    *self = { .arenas = { { a, 0 }, { b, 0 } }, .budget = budget };
}

fn void FrameAllocator.begin_frame(&self)
{
    // TODO: переключить арену, отравить её использованную часть (POISON),
    //       сбросить offset, frame++
    self.frame++;
}

fn void* FrameAllocator.alloc(&self, usz size, usz align)
{
    // TODO: линейное выделение из ТЕКУЩЕЙ арены с лимитом
    //       min(budget, buf.len); при превышении — over_budget++ и null;
    //       обновить peak.
    return null;
}

macro FrameAllocator.new_array(&self, $Type, usz n)
{
    $Type* p = self.alloc($Type::size * n, $Type::alignment);
    return p ? p[:n] : p[:0];
}

// ---------------------------------------------------------------------

struct DrawPacket
{
    uint mesh;
    uint material;
    float depth;
}

struct FramePackets
{
    DrawPacket[] packets;
    ulong frame;
}

fn FramePackets game_frame(FrameAllocator* fa, int count)
{
    DrawPacket[] ps = fa.new_array(DrawPacket, (usz)count);
    foreach (i, &p : ps) *p = { (uint)fa.frame * 100 + (uint)i, (uint)i % 3, (float)i * 0.5f };
    return { ps, fa.frame };
}

fn uint render_frame(FramePackets fp)
{
    uint sum = 0;
    foreach (i, p : fp.packets)
    {
        assert(p.mesh == (uint)fp.frame * 100 + (uint)i, "frame %d packet %d corrupted: mesh=%x", fp.frame, i, p.mesh);
        sum += p.mesh + p.material;
    }
    return sum;
}

fn void main()
{
    char[512] a @align(16);
    char[512] b @align(16);
    FrameAllocator fa;
    fa.init(&a, &b, 400);

    FramePackets in_flight;     // то, что «поток рендера» нарисует в следующем кадре
    uint total = 0;
    int[] counts = { 3, 5, 10, 34, 8, 1, 0, 20 };
    foreach (count : counts)
    {
        fa.begin_frame();
        // Рендер рисует прошлый кадр — его память ещё жива (другая арена).
        uint s = render_frame(in_flight);
        total += s;
        FramePackets next = game_frame(&fa, count);
        io::printfn("frame %d: arena %d, rendered %2d packets (sum %5d), built %2d packets, offset %3d",
                    fa.frame, fa.current, in_flight.packets.len, s, next.packets.len, fa.arenas[fa.current].offset);
        in_flight = next;
    }
    io::printfn("total=%d peak=%d over_budget=%d", total, fa.peak, fa.over_budget);
    assert(fa.over_budget == 1, "34 packets (408 bytes) must exceed the 400 byte budget");
    assert(fa.peak <= 400, "budget must be respected");

    // Висячий указатель: пакеты, построенные два кадра назад, отравлены.
    FramePackets old = game_frame(&fa, 2);     // кадр 8, арена current
    fa.begin_frame();                          // кадр 9 — другая арена, old ещё жив
    assert(old.packets[1].mesh == 801, "data must survive one begin_frame");
    fa.begin_frame();                          // кадр 10 — арена old сброшена
    io::printfn("stale packet mesh = 0x%08x", old.packets[1].mesh);
    assert(old.packets[1].mesh == 0xCDCDCDCD, "stale frame data must be poisoned");
    io::printn("frame allocator OK");
}
