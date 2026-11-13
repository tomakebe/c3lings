// =====================================================================
//  e1306 · Система сохранений: заголовок, CRC32, версии, миграция
// =====================================================================
//
//  Сначала прочитайте engine/docs/13_serialization.md (разделы 13.5, 13.6, 13.10).
//
//  Итог главы: настоящая система сохранений маленькой игры. Всё, что
//  было в e1301–e1305, работает вместе.
//
//  Файл сохранения:
//
//      offset size  поле
//      0      4     magic        "SAV!"
//      4      2     version      1 или 2 (текущая — SAVE_VERSION = 2)
//      6      2     flags        0
//      8      4     payload_size сколько байт после заголовка
//      12     4     crc32        CRC32 payload'а
//      16     ...   payload
//
//  Payload версии 1 (так писала игра на релизе, в мире были тайлы):
//      u32 tick, u16 count, count x { u32 id, i16 tile_x, i16 tile_y, u8 hp }
//
//  Payload версии 2 (после патча: свободное движение, команды, точное hp):
//      u32 tick, varint count, count x { u32 id, f32 x, f32 y, u16 hp, u8 team }
//
//  Миграция v1 -> v2 (смысл полей изменился, default'ом не обойтись):
//      x = tile_x * TILE_SIZE + TILE_SIZE / 2      (центр тайла в мировых единицах)
//      y = tile_y * TILE_SIZE + TILE_SIZE / 2
//      hp = hp_v1 * 10                             (шкала здоровья стала точнее)
//      team = 0                                    (в v1 команд не было)
//
//  Требования:
//   * Загрузчик проверяет всё в порядке «от дешёвого к дорогому»:
//       длина >= заголовка, иначе TRUNCATED; magic, иначе BAD_MAGIC;
//       version в 1..SAVE_VERSION, иначе UNSUPPORTED_VERSION;
//       payload_size == длина - HEADER_SIZE, иначе TRUNCATED;
//       crc32 совпадает, иначе CHECKSUM_MISMATCH;
//       после разбора payload'а не осталось лишних байт, иначе CORRUPT.
//   * Сохранение детерминировано: сущности пишутся отсортированными по id,
//     независимо от порядка в памяти, поэтому один и тот же мир всегда
//     даёт одни и те же байты (и тот же CRC). Поле anim_time — transient,
//     его не сохраняем.
//   * Сохранение пишется только в текущей версии (2). Старые версии
//     только читаются: v1 -> SaveV1 -> migrate_v1_to_v2 -> World.
//
//  ЗАДАЧА: реализуйте crc32, migrate_v1_to_v2, save_game и load_game
//  (места с TODO). Байтовый поток, сортировка, чтение payload'ов v1/v2
//  и «золотой» файл v1 даны.
//
import std::io;
import std::sort;

excuse END_OF_DATA, MALFORMED, TRUNCATED, BAD_MAGIC, UNSUPPORTED_VERSION, CHECKSUM_MISMATCH, CORRUPT;

macro uint @fourcc(String $s) => $s[0] | $s[1] << 8 | $s[2] << 16 | $s[3] << 24;

const uint SAVE_MAGIC = @fourcc("SAV!");
const ushort SAVE_VERSION = 2;
const usz HEADER_SIZE = 16;
const int TILE_SIZE = 16;
const usz MAX_ENTITIES = 16;

// ------------------------------------------------------------ байтовый поток (e1301)

struct ByteWriter
{
    char[512] data;
    usz len;
}
fn void ByteWriter.u8(&self, char v)
{
    assert(self.len < self.data.len, "ByteWriter overflow");
    self.data[self.len++] = v;
}
fn void ByteWriter.u16(&self, ushort v) { self.u8((char)v); self.u8((char)(v >> 8)); }
fn void ByteWriter.u32(&self, uint v) { self.u16((ushort)v); self.u16((ushort)(v >> 16)); }
fn void ByteWriter.f32(&self, float f) => self.u32(bitcast(f, uint));
fn void ByteWriter.varint(&self, uint v)
{
    while (v >= 0x80)
    {
        self.u8((char)(v & 0x7F) | 0x80);
        v >>= 7;
    }
    self.u8((char)v);
}
fn void ByteWriter.patch_u32(&self, usz at, uint v)
{
    for (usz i = 0; i < 4; i++) self.data[at + i] = (char)(v >> (i * 8));
}
fn char[] ByteWriter.bytes(&self) => self.data[:self.len];

struct ByteReader
{
    char[] data;
    usz pos;
}
fn char? ByteReader.u8(&self)
{
    if (self.pos >= self.data.len) return END_OF_DATA~;
    return self.data[self.pos++];
}
fn ushort? ByteReader.u16(&self) { ushort lo = self.u8()!; ushort hi = self.u8()!; return lo | hi << 8; }
fn uint? ByteReader.u32(&self) { uint lo = self.u16()!; uint hi = self.u16()!; return lo | hi << 16; }
fn float? ByteReader.f32(&self) => bitcast(self.u32()!, float);
fn uint? ByteReader.varint(&self)
{
    uint result;
    for (uint shift = 0; shift < 35; shift += 7)
    {
        char b = self.u8()!;
        result |= (uint)(b & 0x7F) << shift;
        if (!(b & 0x80)) return result;
    }
    return MALFORMED~;
}

// ------------------------------------------------------------ CRC32

// CRC-32 (IEEE, как в zlib/PNG): начальное значение 0xFFFFFFFF, отражённый
// полином 0xEDB88320, побитовая обработка, результат инвертируется.
// Контрольное значение: crc32("123456789") == 0xCBF43926.
fn uint crc32(char[] data)
{
    // TODO
    uint crc = 0xFFFF_FFFF;
    foreach (b : data)
    {
        crc ^= b;
        for (int i = 0; i < 8; i++) crc = (crc & 1) ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1;
    }
    return ~crc;
}

// ------------------------------------------------------------ состояние игры (текущее)

struct Entity
{
    uint id;
    float x;
    float y;
    ushort hp;
    char team;
    float anim_time;     // transient: не сохраняется, после загрузки 0
}

struct World
{
    uint tick;
    Entity[MAX_ENTITIES] entities;
    usz count;
}

fn void World.add(&self, Entity e)
{
    assert(self.count < MAX_ENTITIES);
    self.entities[self.count++] = e;
}

fn Entity* World.find(&self, uint id)
{
    foreach (&e : self.entities[:self.count]) if (e.id == id) return e;
    return null;
}

// Копия сущностей, отсортированная по id (для детерминированной записи).
fn Entity[MAX_ENTITIES] World.sorted(&self)
{
    Entity[MAX_ENTITIES] out = self.entities;
    sort::quicksort(out[:self.count], fn int(Entity a, Entity b) => a.id < b.id ? -1 : (int)(a.id > b.id));
    return out;
}

// ------------------------------------------------------------ формат v1 (только чтение)

struct EntityV1
{
    uint id;
    short tile_x;
    short tile_y;
    char hp;
}

struct SaveV1
{
    uint tick;
    EntityV1[MAX_ENTITIES] entities;
    usz count;
}

fn SaveV1? read_payload_v1(ByteReader* r)
{
    SaveV1 s;
    s.tick = r.u32()!;
    ushort count = r.u16()!;
    if (count > MAX_ENTITIES) return CORRUPT~;
    s.count = count;
    foreach (&e : s.entities[:count])
    {
        e.id = r.u32()!;
        e.tile_x = (short)r.u16()!;
        e.tile_y = (short)r.u16()!;
        e.hp = r.u8()!;
    }
    return s;
}

fn World migrate_v1_to_v2(SaveV1* old)
{
    World w;
    // TODO: перенести tick и сущности по правилам из шапки (team = 0, anim_time = 0).
    w.tick = old.tick;
    foreach (e : old.entities[:old.count])
    {
        w.add({
            .id = e.id,
            .x = (float)(e.tile_x * TILE_SIZE + TILE_SIZE / 2),
            .y = (float)(e.tile_y * TILE_SIZE + TILE_SIZE / 2),
            .hp = (ushort)e.hp * 10,
        });
    }
    return w;
}

// ------------------------------------------------------------ формат v2

fn World? read_payload_v2(ByteReader* r)
{
    World w;
    w.tick = r.u32()!;
    uint count = r.varint()!;
    if (count > MAX_ENTITIES) return CORRUPT~;
    for (uint i = 0; i < count; i++)
    {
        Entity e;
        e.id = r.u32()!;
        e.x = r.f32()!;
        e.y = r.f32()!;
        e.hp = r.u16()!;
        e.team = r.u8()!;
        w.add(e);
    }
    return w;
}

fn void save_game(World* world, ByteWriter* w)
{
    // TODO:
    //  1. Заголовок: magic, SAVE_VERSION, flags = 0, затем ДВА места под
    //     payload_size и crc32 (запишите нули и запомните позицию).
    //  2. Payload v2: tick, varint count, сущности из world.sorted() по порядку.
    //  3. Вписать payload_size и crc32(payload) через patch_u32.
    w.u32(SAVE_MAGIC);
    w.u16(SAVE_VERSION);
    w.u16(0);
    usz size_at = w.len;
    w.u32(0);
    w.u32(0);
    usz start = w.len;
    w.u32(world.tick);
    w.varint((uint)world.count);
    Entity[MAX_ENTITIES] ents = world.sorted();
    foreach (e : ents[:world.count])
    {
        w.u32(e.id);
        w.f32(e.x);
        w.f32(e.y);
        w.u16(e.hp);
        w.u8(e.team);
    }
    char[] payload = w.data[start:w.len - start];
    w.patch_u32(size_at, (uint)payload.len);
    w.patch_u32(size_at + 4, crc32(payload));
}

fn World? load_game(char[] file)
{
    // TODO: проверки из шапки по порядку, затем ByteReader по payload'у:
    //   version 1 -> read_payload_v1 + migrate_v1_to_v2, version 2 -> read_payload_v2;
    //   если reader.pos != payload.len -> CORRUPT~.
    if (file.len < HEADER_SIZE) return TRUNCATED~;
    ByteReader h = { .data = file[:HEADER_SIZE] };
    if (h.u32()! != SAVE_MAGIC) return BAD_MAGIC~;
    ushort version = h.u16()!;
    if (version < 1 || version > SAVE_VERSION) return UNSUPPORTED_VERSION~;
    h.u16()!;   // flags
    uint size = h.u32()!;
    uint crc = h.u32()!;
    if (size != file.len - HEADER_SIZE) return TRUNCATED~;
    char[] payload = file[HEADER_SIZE..];
    if (crc32(payload) != crc) return CHECKSUM_MISMATCH~;

    ByteReader r = { .data = payload };
    World w;
    switch (version)
    {
        case 1:
            SaveV1 old = read_payload_v1(&r)!;
            w = migrate_v1_to_v2(&old);
        default:
            w = read_payload_v2(&r)!;
    }
    if (r.pos != payload.len) return CORRUPT~;
    return w;
}

// ------------------------------------------------------------ тесты

// Сохранение, записанное релизной (v1) версией игры. Не меняйте его:
// это контракт с игроками.
const char[] GOLDEN_V1 = {
    0x53, 0x41, 0x56, 0x21, 0x01, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0xfc, 0x72, 0xd2, 0x4c,
    0x39, 0x05, 0x00, 0x00, 0x02, 0x00, 0x0b, 0x00, 0x00, 0x00, 0x03, 0x00, 0x04, 0x00, 0x14, 0x05,
    0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x07,
};

fn void hexdump(char[] bytes)
{
    foreach (i, b : bytes)
    {
        io::printf("%02x", b);
        io::print((i % 16 == 15 || i + 1 == bytes.len) ? "\n" : " ");
    }
}

fn void print_world(String label, World* w)
{
    io::printfn("%s: tick=%d entities=%d", label, w.tick, w.count);
    Entity[MAX_ENTITIES] ents = w.sorted();
    foreach (e : ents[:w.count])
    {
        io::printfn("  #%d pos=(%.2f, %.2f) hp=%d team=%d", e.id, e.x, e.y, e.hp, e.team);
    }
}

macro void @expect_err(String what, #expr)
{
    if (catch e = #expr)
    {
        io::printfn("%s: %s", what, e);
        return;
    }
    unreachable("expected an error: %s", what);
}

fn void main()
{
    assert(crc32("123456789") == 0xCBF43926, "crc32 check value");
    assert(crc32("") == 0);
    io::printfn("crc32(\"123456789\") = %08x", crc32("123456789"));

    // --- текущая версия: сохранить и загрузить ---
    World world = { .tick = 4242 };
    world.add({ .id = 30, .x = 100.5, .y = -7.25, .hp = 900, .team = 2, .anim_time = 0.75 });
    world.add({ .id = 4,  .x = 0,     .y = 0,     .hp = 1,   .team = 1, .anim_time = 0.5 });
    world.add({ .id = 17, .x = 33,    .y = 64,    .hp = 250, .team = 1 });

    ByteWriter w;
    save_game(&world, &w);
    char[] file = w.bytes();
    io::printfn("v2 save: %d bytes", file.len);
    hexdump(file);

    // Другой порядок в памяти -> те же байты.
    World shuffled = { .tick = 4242 };
    shuffled.add(world.entities[2]);
    shuffled.add(world.entities[0]);
    shuffled.add(world.entities[1]);
    ByteWriter w2;
    save_game(&shuffled, &w2);
    assert(w2.bytes() == file, "save must not depend on in-memory order");

    World loaded = load_game(file)!!;
    assert(loaded.tick == 4242 && loaded.count == 3);
    Entity* e30 = loaded.find(30);
    assert(e30 && e30.x == 100.5f && e30.y == -7.25f && e30.hp == 900 && e30.team == 2);
    assert(e30.anim_time == 0, "anim_time is transient");
    print_world("loaded v2", &loaded);

    // --- золотой файл v1 + миграция ---
    World old = load_game(GOLDEN_V1)!!;
    assert(old.tick == 1337 && old.count == 2);
    Entity* e11 = old.find(11);
    assert(e11 && e11.x == 56 && e11.y == 72 && e11.hp == 200 && e11.team == 0);
    Entity* e5 = old.find(5);
    assert(e5 && e5.x == -8 && e5.y == 8 && e5.hp == 70);
    print_world("migrated v1", &old);

    // После миграции игра сохраняет уже в v2 — и это тоже загружается.
    ByteWriter w3;
    save_game(&old, &w3);
    World again = load_game(w3.bytes())!!;
    assert(again.count == 2 && again.find(11).hp == 200);
    io::printfn("v1 -> v2 resave: %d bytes", w3.len);

    // --- повреждения ---
    char[512] buf;
    usz n = file.len;
    @expect_err("empty file", load_game(buf[:0]));
    buf[:n] = file[..];
    buf[0] = 'Z';
    @expect_err("wrong magic", load_game(buf[:n]));
    buf[:n] = file[..];
    buf[4] = 9;
    @expect_err("from the future", load_game(buf[:n]));
    @expect_err("cut off", load_game(file[:n - 3]));
    buf[:n] = file[..];
    buf[n - 1] ^= 0x01;      // один бит в team последней сущности
    @expect_err("bit flip", load_game(buf[:n]));

    // Payload с лишним байтом и честно пересчитанными size/crc: файл
    // цел, но не соответствует схеме.
    buf[:n] = file[..];
    buf[n] = 0;
    ByteWriter fix;
    fix.data[:n + 1] = buf[:n + 1];
    fix.len = n + 1;
    fix.patch_u32(8, (uint)(n + 1 - HEADER_SIZE));
    fix.patch_u32(12, crc32(fix.data[HEADER_SIZE:n + 1 - HEADER_SIZE]));
    @expect_err("trailing garbage", load_game(fix.bytes()));

    io::printn("save game ok");
}
