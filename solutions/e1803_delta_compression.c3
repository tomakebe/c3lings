// =====================================================================
//  e1803 · Дельта-сжатие снапшотов
// =====================================================================
//
//  Сервер шлёт клиенту СНАПШОТ мира 20–60 раз в секунду. Но за 1/20 с
//  меняется малая часть мира: большинство сущностей стоят, у
//  движущихся меняется позиция, а здоровье — редко. Поэтому сервер
//  шлёт РАЗНИЦУ с «базой» (baseline) — снапшотом, который клиент точно
//  получил:
//
//      сервер:  snap 10   snap 11   snap 12   snap 13 ...
//      клиент:  ack 10 -----------------> сервер: «база для клиента = 10»
//      сервер:  snap 14 = delta(10 -> 14) + номер базы 10
//
//  База — последний ПОДТВЕРЖДЁННЫЙ снапшот (e1802), а не предыдущий
//  отправленный: предыдущий мог потеряться, и тогда клиент не сможет
//  раскодировать дельту. Клиент хранит кольцо последних полученных
//  снапшотов и раскодирует относительно того, номер которого указан
//  в пакете. Если подтверждённой базы нет — дельта от «нулевого»
//  снапшота (по сути полный снапшот).
//
//  Формат дельты для каждой сущности:
//
//      1 бит  changed?            0 -> сущность как в базе, дальше ничего
//      1 бит  x changed?   [16 бит x]
//      1 бит  y changed?   [16 бит y]
//      1 бит  hp changed?  [7 бит hp]
//
//  Неизменная сущность стоит 1 бит вместо 39. Дальше этот подход
//  развивают: кодируют разность значений меньшим числом бит,
//  предсказывают позицию по скорости и шлют только ошибку, и т.д.
//
//  ЗАДАЧА: реализуйте encode_delta и decode_delta.
//
import std::io;

const int ENTITIES = 8;
const int RING = 32;

struct Entity { uint x; uint y; uint hp; }   // x,y: 16 бит, hp: 7 бит
struct Snapshot { int tick; Entity[ENTITIES] e; }

// --- простой битовый поток (как в e1801, готов)
struct Bits { uint[64] words; int count; }
fn void Bits.put(&self, uint v, int n)
{
    for (int i = 0; i < n; i++)
    {
        if ((v >> i) & 1) self.words[(self.count + i) / 32] |= 1u << ((self.count + i) % 32);
    }
    self.count += n;
}
struct BitsIn { Bits* b; int pos; }
fn uint BitsIn.get(&self, int n)
{
    uint v = 0;
    for (int i = 0; i < n; i++)
    {
        int p = self.pos + i;
        if ((self.b.words[p / 32] >> (p % 32)) & 1) v |= 1u << i;
    }
    self.pos += n;
    return v;
}

fn void encode_delta(Snapshot* base, Snapshot* cur, Bits* out)
{
    for (int i = 0; i < ENTITIES; i++)
    {
        Entity b = base.e[i];
        Entity c = cur.e[i];
        bool cx = b.x != c.x;
        bool cy = b.y != c.y;
        bool ch = b.hp != c.hp;
        if (!cx && !cy && !ch) { out.put(0, 1); continue; }
        out.put(1, 1);
        out.put(cx ? 1 : 0, 1);
        if (cx) out.put(c.x, 16);
        out.put(cy ? 1 : 0, 1);
        if (cy) out.put(c.y, 16);
        out.put(ch ? 1 : 0, 1);
        if (ch) out.put(c.hp, 7);
    }
}

fn void decode_delta(Snapshot* base, BitsIn* in, Snapshot* out)
{
    for (int i = 0; i < ENTITIES; i++)
    {
        out.e[i] = base.e[i];
        if (in.get(1) == 0) continue;
        if (in.get(1)) out.e[i].x = in.get(16);
        if (in.get(1)) out.e[i].y = in.get(16);
        if (in.get(1)) out.e[i].hp = in.get(7);
    }
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

struct Lcg { uint state; }
fn uint Lcg.next(&self) { self.state = self.state * 1103515245 + 12345; return (self.state >> 16) & 0x7FFF; }

fn bool same(Snapshot* a, Snapshot* b)
{
    for (int i = 0; i < ENTITIES; i++)
    {
        if (a.e[i].x != b.e[i].x || a.e[i].y != b.e[i].y || a.e[i].hp != b.e[i].hp) return false;
    }
    return true;
}

fn void main()
{
    Snapshot zero;
    Snapshot[RING] server_hist;
    Snapshot[RING] client_hist;
    int client_acked = -1;     // последний тик, подтверждение которого ДОШЛО до сервера
    Lcg rng = { 777 };

    // начальный мир
    Snapshot world;
    for (int i = 0; i < ENTITIES; i++) world.e[i] = { (uint)(1000 * i), 500, 100 };

    int total_bits = 0;
    int full_bits = 0;
    for (int tick = 0; tick < 20; tick++)
    {
        // мир меняется: сущности 0 и 1 бегут, 5 иногда получает урон
        world.tick = tick;
        world.e[0].x += 7;
        world.e[1].y = (world.e[1].y + 3) & 0xFFFF;
        if (tick % 6 == 5) world.e[5].hp -= 10;
        server_hist[tick % RING] = world;

        // сервер кодирует относительно последнего подтверждённого
        Snapshot* base = client_acked >= 0 ? &server_hist[client_acked % RING] : &zero;
        Bits pkt;
        encode_delta(base, &world, &pkt);
        Bits full;
        encode_delta(&zero, &world, &full);
        total_bits += pkt.count;
        full_bits += full.count;

        bool lost = rng.next() % 100 < 25;
        if (!lost)
        {
            // клиент раскодирует относительно той же базы (номер базы — в пакете)
            Snapshot* cbase = client_acked >= 0 ? &client_hist[client_acked % RING] : &zero;
            BitsIn in = { &pkt, 0 };
            Snapshot got;
            decode_delta(cbase, &in, &got);
            got.tick = tick;
            assert(in.pos == pkt.count, "прочитано столько же бит, сколько записано");
            assert(same(&got, &world), "клиент должен восстановить снапшот тика %d", tick);
            client_hist[tick % RING] = got;
            // ack клиента доходит до сервера не всегда
            if (rng.next() % 100 >= 30) client_acked = tick;
        }
        io::printfn("tick %2d base=%3d bits=%3d%s", tick, base == &zero ? -1 : base.tick, pkt.count, lost ? " (lost)" : "");
    }
    io::printfn("delta total: %d bits, full snapshots: %d bits (%d%%)", total_bits, full_bits, total_bits * 100 / full_bits);
}
