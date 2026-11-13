// =====================================================================
//  e1703 · Изменилась раскладка состояния: миграция при перезагрузке
// =====================================================================
//
//  Самое коварное в горячей перезагрузке: вы добавили поле в структуру
//  состояния и пересобрали модуль. Новый код думает, что `health`
//  лежит по смещению 8, а в памяти хоста там лежит старое поле `ammo`.
//  Никакой ошибки — просто тихо перепутанные данные.
//
//      v1:  | x | y | ammo |                 (12 байт)
//      v2:  | x | y | health | ammo | team | (20 байт)
//                     ^^^^^^ новый код читает ammo как health!
//
//  Варианты защиты (от простого к сложному):
//    1. Перезапуск игры при изменении раскладки (Handmade Hero: проще
//       всего, и честно — горячая перезагрузка нужна для ЛОГИКИ).
//    2. Заголовок состояния {magic, version, size} в начале постоянной
//       памяти + миграция: новый модуль видит старую версию и
//       переносит данные поле за полем, новым полям — значения по
//       умолчанию. Это то же версионирование, что в главе 13.
//    3. Рефлексия: модуль описывает раскладку (имя, тип, смещение
//       каждого поля), и миграция делается автоматически по ИМЕНАМ.
//
//  Мы делаем вариант 2. Миграция делается через временный буфер:
//  новая раскладка БОЛЬШЕ старой и перекрывается с ней в памяти,
//  поэтому писать «на месте» нельзя.
//
//  ЗАДАЧА: реализуйте migrate_v1_to_v2 и on_load_v2.
//
import std::io;

const uint STATE_MAGIC = 0x53544154;   // "STAT"
const int MAX_UNITS = 4;

struct StateHeader
{
    uint magic;
    uint version;
    usz size;
}

struct UnitV1 { int x; int y; int ammo; }
struct StateV1
{
    StateHeader header;
    int unit_count;
    UnitV1[MAX_UNITS] units;
}

struct UnitV2 { int x; int y; int health; int ammo; int team; }
struct StateV2
{
    StateHeader header;
    int unit_count;
    UnitV2[MAX_UNITS] units;
    int migrations;     // сколько раз состояние мигрировало
}

// Постоянная память хоста. Сырые байты: какой тип там лежит, говорит
// только заголовок.
struct HostMemory
{
    char[512] bytes @align(16);
}

fn StateHeader* header_of(HostMemory* m) => (StateHeader*)&m.bytes;

// --- «модуль v1»
fn void on_load_v1(HostMemory* m)
{
    StateV1* s = (StateV1*)&m.bytes;
    if (s.header.magic != STATE_MAGIC) *s = { .header = { STATE_MAGIC, 1, StateV1::size } };
    assert(s.header.version == 1);
}

fn void spawn_v1(HostMemory* m, int x, int y, int ammo)
{
    StateV1* s = (StateV1*)&m.bytes;
    s.units[s.unit_count++] = { x, y, ammo };
}

// --- «модуль v2»
fn void migrate_v1_to_v2(StateV1* old, StateV2* out)
{
    // TODO: заголовок v2, копирование полей, health = 100, team = i % 2
    (void)old;
    (void)out;
}

fn void on_load_v2(HostMemory* m)
{
    StateHeader* h = header_of(m);
    // TODO: нет magic -> чистое состояние v2; версия 1 -> миграция через
    // временную StateV2 (migrations++); версия 2 -> ничего не делать.
    (void)h;
}

fn void spawn_v2(HostMemory* m, int x, int y)
{
    StateV2* s = (StateV2*)&m.bytes;
    s.units[s.unit_count++] = { x, y, 100, 30, 1 };
}

fn void main()
{
    $assert StateV2::size <= HostMemory::size;
    HostMemory mem;

    on_load_v1(&mem);
    spawn_v1(&mem, 1, 2, 30);
    spawn_v1(&mem, 5, 6, 12);
    spawn_v1(&mem, -3, 4, 0);

    // перезагрузка в v2
    on_load_v2(&mem);
    StateV2* s = (StateV2*)&mem.bytes;
    assert(s.header.version == 2 && s.migrations == 1, "должна была пройти миграция");
    assert(s.unit_count == 3 && s.units[1].ammo == 12 && s.units[1].health == 100);
    assert(s.units[2].x == -3 && s.units[2].team == 0 && s.units[1].team == 1);

    // повторная перезагрузка той же версии — без миграции
    on_load_v2(&mem);
    assert(s.migrations == 1, "v2 -> v2 мигрировать не нужно");
    spawn_v2(&mem, 9, 9);

    // чистая память — сразу v2
    HostMemory fresh;
    on_load_v2(&fresh);
    assert(((StateV2*)&fresh.bytes).header.version == 2 && ((StateV2*)&fresh.bytes).unit_count == 0);

    io::printfn("v1 size=%d, v2 size=%d", StateV1::size, StateV2::size);
    for (int i = 0; i < s.unit_count; i++)
    {
        UnitV2 u = s.units[i];
        io::printfn("unit %d: pos=(%d,%d) hp=%d ammo=%d team=%d", i, u.x, u.y, u.health, u.ammo, u.team);
    }
}
