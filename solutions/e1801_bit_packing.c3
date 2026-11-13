// =====================================================================
//  e1801 · Упаковка битов и квантование
// =====================================================================
//
//  Пропускная способность — главный ресурс сетевой игры. Пакет UDP,
//  который гарантированно не фрагментируется в интернете, — около
//  1200 байт; отправлять его 20–60 раз в секунду на каждого из 64
//  игроков. Поэтому каждый БИТ на счету.
//
//  Два инструмента:
//
//  1) БИТОВЫЙ ПОТОК. Логическое значение — 1 бит, а не байт; номер
//     оружия из 12 — 4 бита; здоровье 0..100 — 7 бит. Писатель
//     накапливает биты в 64-битном «scratch» и сбрасывает полные
//     32-битные слова в буфер:
//
//        scratch (биты заполняются от младших к старшим)
//        [........................ccccbbbbbbbaaa]   a=3 бита, b=7, c=4
//                                     ^ scratch_bits = 14
//        когда scratch_bits >= 32 -> words[n++] = (uint)scratch;
//                                    scratch >>= 32; scratch_bits -= 32
//
//     Читатель делает то же самое в обратную сторону. Порядок чтения
//     ОБЯЗАН совпадать с порядком записи — формат пакета задаётся
//     кодом, а не самоописанием (это экономит биты).
//
//  2) КВАНТОВАНИЕ. Позиция на карте 0..1000 м с точностью 1 см — это
//     100001 вариант, т.е. 17 бит вместо 32 у float:
//
//        q = round((x - min) / (max - min) * (2^bits - 1))
//        x' = min + q / (2^bits - 1) * (max - min)
//
//     Ошибка не превышает половины шага. Важно: сервер должен
//     симулировать с УЖЕ квантованными значениями (или клиент
//     получает чуть другое состояние, чем у сервера).
//
//  ЗАДАЧА: реализуйте BitWriter.write, BitWriter.flush, BitReader.read,
//  quantize и dequantize.
//
import std::io, std::math;

struct BitWriter
{
    uint[64] words;
    int word_count;
    ulong scratch;
    int scratch_bits;
    int total_bits;
}

// Записать младшие `bits` бит value (1..32).
fn void BitWriter.write(&self, uint value, int bits)
{
    assert(bits >= 1 && bits <= 32);
    assert(bits == 32 || value < (1u << bits), "значение не влезает в %d бит", bits);
    self.scratch |= (ulong)value << self.scratch_bits;
    self.scratch_bits += bits;
    self.total_bits += bits;
    if (self.scratch_bits >= 32)
    {
        self.words[self.word_count++] = (uint)self.scratch;
        self.scratch >>= 32;
        self.scratch_bits -= 32;
    }
}

// Сбросить остаток scratch (если он есть) последним словом.
fn void BitWriter.flush(&self)
{
    if (self.scratch_bits > 0)
    {
        self.words[self.word_count++] = (uint)self.scratch;
        self.scratch = 0;
        self.scratch_bits = 0;
    }
}

fn int BitWriter.bytes(&self) => (self.total_bits + 7) / 8;

struct BitReader
{
    uint[] words;
    int word_index;
    ulong scratch;
    int scratch_bits;
}

fn uint BitReader.read(&self, int bits)
{
    assert(bits >= 1 && bits <= 32);
    if (self.scratch_bits < bits)
    {
        self.scratch |= (ulong)self.words[self.word_index++] << self.scratch_bits;
        self.scratch_bits += 32;
    }
    uint v = (uint)(self.scratch & ((1ul << bits) - 1));
    self.scratch >>= bits;
    self.scratch_bits -= bits;
    return v;
}

fn uint quantize(float x, float min, float max, int bits)
{
    if (x < min) x = min;
    if (x > max) x = max;
    float steps = (float)((1u << bits) - 1);
    return (uint)math::round((x - min) / (max - min) * steps);
}

fn float dequantize(uint q, float min, float max, int bits)
{
    float steps = (float)((1u << bits) - 1);
    return min + (float)q / steps * (max - min);
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

struct PlayerState
{
    bool alive;
    int health;      // 0..100      -> 7 бит
    int weapon;      // 0..11       -> 4 бита
    float x;         // 0..1000 м   -> 17 бит (шаг ~0.8 см)
    float angle;     // 0..360 град -> 9 бит (шаг ~0.7 град)
}

fn void write_player(BitWriter* w, PlayerState* p)
{
    w.write(p.alive ? 1 : 0, 1);
    if (!p.alive) return;     // мёртвым остальное не нужно — экономия
    w.write((uint)p.health, 7);
    w.write((uint)p.weapon, 4);
    w.write(quantize(p.x, 0, 1000, 17), 17);
    w.write(quantize(p.angle, 0, 360, 9), 9);
}

fn PlayerState read_player(BitReader* r)
{
    PlayerState p;
    p.alive = r.read(1) == 1;
    if (!p.alive) return p;
    p.health = (int)r.read(7);
    p.weapon = (int)r.read(4);
    p.x = dequantize(r.read(17), 0, 1000, 17);
    p.angle = dequantize(r.read(9), 0, 360, 9);
    return p;
}

fn void main()
{
    // базовый тест потока, включая значения, пересекающие границу слова
    BitWriter w;
    w.write(5, 3);
    w.write(0x1FFFFFFF, 29);   // ровно 32 бита
    w.write(0xABCDE, 20);
    w.write(1, 1);
    w.write(0xDEADBEEF, 32);
    w.flush();
    assert(w.total_bits == 85 && w.word_count == 3);
    BitReader r = { .words = w.words[:w.word_count] };
    assert(r.read(3) == 5);
    assert(r.read(29) == 0x1FFFFFFF);
    assert(r.read(20) == 0xABCDE);
    assert(r.read(1) == 1);
    assert(r.read(32) == 0xDEADBEEF, "32 бита через границу слова");
    io::printn("bitstream: ok");

    assert(quantize(0, 0, 1000, 17) == 0 && quantize(1000, 0, 1000, 17) == 131071);
    assert(quantize(-5, 0, 1000, 17) == 0 && quantize(5000, 0, 1000, 17) == 131071, "clamp");
    float back = dequantize(quantize(123.456f, 0, 1000, 17), 0, 1000, 17);
    assert(math::abs(back - 123.456f) < 0.004f, "ошибка не больше половины шага");

    PlayerState[*] players = {
        { true, 100, 3, 12.5f, 90 },
        { false, 0, 0, 0, 0 },
        { true, 37, 11, 999.99f, 359.5f },
        { true, 1, 0, 500.0f, 0.3f },
    };
    BitWriter pw;
    foreach (&p : players) write_player(&pw, p);
    pw.flush();
    int naive = (int)(players.len * PlayerState::size);
    io::printfn("packed %d players: %d bits = %d bytes (naive struct copy: %d bytes)", players.len, pw.total_bits, pw.bytes(), naive);

    BitReader pr = { .words = pw.words[:pw.word_count] };
    foreach (i, &p : players)
    {
        PlayerState q = read_player(&pr);
        assert(q.alive == p.alive && q.health == p.health && q.weapon == p.weapon);
        assert(math::abs(q.x - p.x) < 0.004f && math::abs(q.angle - p.angle) < 0.36f);
        io::printfn("player %d: alive=%s hp=%d weapon=%d x=%.2f angle=%.1f", i, q.alive, q.health, q.weapon, q.x, q.angle);
    }
}
