// =====================================================================
//  e1302 · Чанковый формат и эволюция схемы
// =====================================================================
//
//  Сначала прочитайте engine/docs/13_serialization.md (разделы 13.4–13.5).
//
//  Файл уровня устроен как IFF/RIFF/PNG: заголовок, потом цепочка чанков
//
//      "MAPS" u16 version | fourcc u32 | size u32 | payload ... | fourcc | size | ...
//
//  Чанки, которые знает наш загрузчик:
//      NAME  u8 len, len байт ASCII              (обязателен)
//      SIZE  u16 width, u16 height               (обязателен; версия 3 дописала
//                                                 в конец u16 depth — мы о нём не знаем)
//      GRAV  f32 gravity                         (появился в версии 2; если его нет,
//                                                 gravity = DEFAULT_GRAVITY)
//  Всё остальное — чанки из будущих версий: их надо ПРОПУСТИТЬ и посчитать.
//
//  Три правила, ради которых упражнение написано:
//   1. После разбора чанка позиция ставится в `start + size`, а не туда,
//      где закончилось наше чтение: так мы переживаем расширенные чанки.
//   2. Незнакомый чанк — не ошибка: перепрыгнуть `size` байт (прямая совместимость).
//   3. Отсутствующий необязательный чанк — значение по умолчанию (обратная
//      совместимость); отсутствующий обязательный — ошибка MISSING_CHUNK.
//  И, конечно, `size`, выходящий за конец файла, — ошибка END_OF_DATA, а
//  неверный magic — BAD_MAGIC.
//
//  Писатель использует приём «зарезервировать место под размер и
//  дописать его потом» (backpatching): begin_chunk пишет fourcc и 0,
//  запоминает позицию, а end_chunk вписывает настоящий размер payload'а.
//
//  ЗАДАЧА: реализуйте ByteWriter.end_chunk и load_level (места с TODO).
//
import std::io;

excuse END_OF_DATA, BAD_MAGIC, MISSING_CHUNK;

const float DEFAULT_GRAVITY = 9.8f;

macro uint @fourcc(String $s) => $s[0] | $s[1] << 8 | $s[2] << 16 | $s[3] << 24;

const uint MAGIC = @fourcc("MAPS");
const uint TAG_NAME = @fourcc("NAME");
const uint TAG_SIZE = @fourcc("SIZE");
const uint TAG_GRAV = @fourcc("GRAV");

// ------------------------------------------------------------ байтовый поток (из e1301)

struct ByteWriter
{
    char[256] data;
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
fn void ByteWriter.str(&self, String s)
{
    self.u8((char)s.len);
    foreach (c : s) self.u8(c);
}
fn void ByteWriter.patch_u32(&self, usz at, uint v)
{
    for (usz i = 0; i < 4; i++) self.data[at + i] = (char)(v >> (i * 8));
}
fn char[] ByteWriter.bytes(&self) => self.data[:self.len];

// Возвращает позицию поля size; её надо передать в end_chunk.
fn usz ByteWriter.begin_chunk(&self, uint tag)
{
    self.u32(tag);
    usz at = self.len;
    self.u32(0);        // место под размер, впишем позже
    return at;
}

fn void ByteWriter.end_chunk(&self, usz size_at)
{
    // TODO: payload начинается сразу после 4 байт поля size и кончается на self.len.
    //       Впишите его длину в поле size через patch_u32.
}

struct ByteReader
{
    char[] data;
    usz pos;
}

fn usz ByteReader.remaining(&self) => self.data.len - self.pos;
fn char? ByteReader.u8(&self)
{
    if (self.pos >= self.data.len) return END_OF_DATA~;
    return self.data[self.pos++];
}
fn ushort? ByteReader.u16(&self) { ushort lo = self.u8()!; ushort hi = self.u8()!; return lo | hi << 8; }
fn uint? ByteReader.u32(&self) { uint lo = self.u16()!; uint hi = self.u16()!; return lo | hi << 16; }
fn float? ByteReader.f32(&self) => bitcast(self.u32()!, float);

// ------------------------------------------------------------ уровень

struct Level
{
    ushort version;
    char[32] name_buf;
    usz name_len;
    ushort width;
    ushort height;
    float gravity;
    int skipped_chunks;
}

fn String Level.name(&self) => (String)self.name_buf[:self.name_len];

fn void? read_name(ByteReader* r, Level* lvl)
{
    char len = r.u8()!;
    if (len > lvl.name_buf.len) return END_OF_DATA~;
    for (usz i = 0; i < len; i++) lvl.name_buf[i] = r.u8()!;
    lvl.name_len = len;
}

fn Level? load_level(char[] data)
{
    ByteReader r = { .data = data };
    Level lvl = { .gravity = DEFAULT_GRAVITY };
    // TODO:
    //  1. Прочитать magic (u32) и сравнить с MAGIC, иначе BAD_MAGIC~.
    //     Прочитать version (u16) в lvl.version.
    //  2. Пока r.remaining() > 0:
    //       tag = u32, size = u32; если size > r.remaining() -> END_OF_DATA~;
    //       запомнить end = r.pos + size;
    //       switch (tag): NAME -> read_name, SIZE -> width/height,
    //                     GRAV -> gravity, default -> lvl.skipped_chunks++;
    //       r.pos = end;   // правило 1 и 2 одной строкой
    //  3. Если не было NAME или SIZE -> MISSING_CHUNK~.
    return lvl;
}

// ------------------------------------------------------------ "старые" и "новые" писатели

fn void write_header(ByteWriter* w, ushort version)
{
    w.u32(MAGIC);
    w.u16(version);
}

fn void write_v1(ByteWriter* w)
{
    write_header(w, 1);
    usz c = w.begin_chunk(TAG_NAME); w.str("arena"); w.end_chunk(c);
    c = w.begin_chunk(TAG_SIZE); w.u16(32); w.u16(16); w.end_chunk(c);
}

fn void write_v2(ByteWriter* w)
{
    write_header(w, 2);
    usz c = w.begin_chunk(TAG_SIZE); w.u16(64); w.u16(48); w.end_chunk(c);   // порядок чанков не важен
    c = w.begin_chunk(TAG_NAME); w.str("moon base"); w.end_chunk(c);
    c = w.begin_chunk(TAG_GRAV); w.f32(1.625f); w.end_chunk(c);
}

// Версия 3 из «будущего»: новые чанки META и TAGS, расширенный SIZE.
fn void write_v3(ByteWriter* w)
{
    write_header(w, 3);
    usz c = w.begin_chunk(@fourcc("META")); w.str("author: level designer"); w.end_chunk(c);
    c = w.begin_chunk(TAG_NAME); w.str("tower"); w.end_chunk(c);
    c = w.begin_chunk(TAG_SIZE); w.u16(20); w.u16(20); w.u16(12); w.end_chunk(c);  // + depth
    c = w.begin_chunk(TAG_GRAV); w.f32(12.5f); w.end_chunk(c);
    c = w.begin_chunk(@fourcc("TAGS")); w.u8(2); w.u8(7); w.u8(9); w.end_chunk(c);
}

fn void print_level(String label, Level* l)
{
    io::printfn("%s: v%d '%s' %dx%d gravity=%.3f skipped=%d",
                label, l.version, l.name(), l.width, l.height, l.gravity, l.skipped_chunks);
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
    ByteWriter w1;
    write_v1(&w1);
    // Проверяем backpatching: размер первого чанка NAME = 1 + 5 байт.
    char[] b1 = w1.bytes();
    assert(b1[10] == 6 && b1[11] == 0, "end_chunk must patch the payload size");
    io::printfn("v1 file: %d bytes", b1.len);

    Level l1 = load_level(b1)!!;
    assert(l1.name() == "arena" && l1.width == 32 && l1.height == 16);
    assert(l1.gravity == DEFAULT_GRAVITY, "missing GRAV must give the default");
    print_level("v1", &l1);

    ByteWriter w2;
    write_v2(&w2);
    Level l2 = load_level(w2.bytes())!!;
    assert(l2.name() == "moon base" && l2.width == 64 && l2.gravity == 1.625f);
    print_level("v2", &l2);

    ByteWriter w3;
    write_v3(&w3);
    Level l3 = load_level(w3.bytes())!!;
    assert(l3.name() == "tower" && l3.width == 20 && l3.height == 20, "extended SIZE chunk");
    assert(l3.gravity == 12.5f, "GRAV after an extended chunk must still be found");
    assert(l3.skipped_chunks == 2);
    print_level("v3", &l3);

    // --- испорченные файлы ---
    char[] bad = w1.bytes();
    char[64] copy;
    copy[:bad.len] = bad[..];
    copy[0] = 'X';
    @expect_err("bad magic", load_level(copy[:bad.len]));
    @expect_err("truncated", load_level(bad[:bad.len - 2]));

    ByteWriter w4;
    write_header(&w4, 2);
    usz c = w4.begin_chunk(TAG_NAME); w4.str("nameless?"); w4.end_chunk(c);
    @expect_err("no SIZE chunk", load_level(w4.bytes()));

    io::printn("chunks ok");
}
