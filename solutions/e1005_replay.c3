// =====================================================================
//  e1005 · Запись и воспроизведение ввода (реплеи)
// =====================================================================
//
//  Сначала прочитайте engine/docs/10_input.md (раздел «Запись ввода и
//  реплеи») и вспомните главу 01 про детерминизм.
//
//  Если симуляция детерминирована (фиксированный шаг, целочисленная
//  математика, ГСЧ с известным seed, никаких зависимостей от времени и
//  адресов), то для полного повтора матча достаточно сохранить:
//
//      seed + ввод каждого кадра
//
//  Так устроены реплеи StarCraft, Age of Empires, Rocket League (частично),
//  Doom-демо (.lmp — буквально поток тиккомманд), Trackmania, а также
//  «killcam» и автотесты геймплея во многих студиях. Это же основа
//  lockstep-сети (глава 18).
//
//  Ввод — после action mapping: ushort-маска действий на кадр. Подряд
//  идущие кадры почти всегда одинаковы (игрок держит «вправо» полсекунды),
//  поэтому храним RLE: { mask, count }. 600 кадров превращаются в
//  несколько десятков пар.
//
//  Главная беда реплеев — рассинхрон (desync): малейшее отличие
//  (другая версия кода, неинициализированная переменная, float на другом
//  CPU) — и реплей «уплывает», причём заметно это бывает через минуты.
//  Поэтому при записи каждые CHECKPOINT кадров сохраняют хеш состояния
//  симуляции, а при воспроизведении сверяют: первый несовпавший
//  чекпоинт локализует рассинхрон с точностью до CHECKPOINT кадров.
//
//  Формат файла replay.bin (little-endian), уже написан:
//      "C3RP"  u32 version  u32 seed  u32 frames
//      u32 run_count    run_count * (u16 mask, u16 count)
//      u32 cp_count     cp_count  * u32 hash
//
//  ЗАДАЧА: реализуйте (TODO)
//    * Replay.record_frame — дописать маску кадра в RLE;
//    * Playback.next       — выдать маску следующего кадра или
//                            END_OF_REPLAY~;
//    * verify              — воспроизвести реплей на свежей симуляции
//                            и вернуть номер кадра первого несовпавшего
//                            чекпоинта (или -1, если всё сошлось).
//
import std::io;
import std::collections::list;

// ------------------------------------------------------------ симуляция

const ushort ACT_LEFT  = 1;
const ushort ACT_RIGHT = 2;
const ushort ACT_JUMP  = 4;
const ushort ACT_FIRE  = 8;

const uint CHECKPOINT = 60;

struct Rng { uint state; }
fn uint Rng.next(&self)
{
    self.state = self.state * 1664525 + 1013904223;
    return self.state >> 8;
}

struct Sim
{
    Rng rng;
    uint frame;
    int x, y, vy;
    int ammo;
    int score;
    int enemy_x;
}

fn void Sim.init(&self, uint seed)
{
    *self = { .rng = { seed }, .x = 500, .ammo = 10 };
    self.enemy_x = (int)(self.rng.next() % 1000);
}

fn void Sim.step(&self, ushort input)
{
    if (input & ACT_LEFT) self.x -= 7;
    if (input & ACT_RIGHT) self.x += 7;
    if (self.x < 0) self.x = 0;
    if (self.x > 1000) self.x = 1000;
    if (input & ACT_JUMP && self.y == 0) self.vy = 12;
    self.y += self.vy;
    self.vy -= 1;
    if (self.y <= 0)
    {
        self.y = 0;
        self.vy = 0;
    }
    if (input & ACT_FIRE && self.ammo > 0)
    {
        self.ammo--;
        int d = self.enemy_x - self.x;
        if (d > -120 && d < 120)
        {
            self.score += 10;
            self.enemy_x = (int)(self.rng.next() % 1000);
        }
    }
    self.frame++;
    if (self.frame % 120 == 0 && self.ammo < 20) self.ammo += 5;
}

fn uint Sim.hash(&self)
{
    uint h = 2166136261;
    int[*] fields = { (int)self.rng.state, (int)self.frame, self.x, self.y, self.vy, self.ammo, self.score, self.enemy_x };
    foreach (f : fields)
    {
        for (int b = 0; b < 32; b += 8)
        {
            h = (h ^ ((uint)f >> b & 0xFF)) * 16777619;
        }
    }
    return h;
}

// ------------------------------------------------------------ реплей

struct Run
{
    ushort mask;
    ushort count;
}

struct Replay
{
    uint seed;
    uint frames;
    List{Run} runs;
    List{uint} checkpoints;
}

fn void Replay.free(&self)
{
    self.runs.free();
    self.checkpoints.free();
}

fn void Replay.record_frame(&self, ushort mask)
{
    self.frames++;
    sz n = self.runs.len();
    if (n > 0)
    {
        Run* last = &self.runs[n - 1];
        if (last.mask == mask && last.count < ushort::max)
        {
            last.count++;
            return;
        }
    }
    self.runs.push({ mask, 1 });
}

excuse END_OF_REPLAY;

struct Playback
{
    Replay* replay;
    sz run;        // текущий Run
    ushort used;   // сколько кадров текущего Run уже выдано
}

fn ushort? Playback.next(&self)
{
    Replay* r = self.replay;
    while (self.run < r.runs.len() && self.used >= r.runs[self.run].count)
    {
        self.run++;
        self.used = 0;
    }
    if (self.run >= r.runs.len()) return END_OF_REPLAY~;
    self.used++;
    return r.runs[self.run].mask;
}

<*
 @return "кадр первого несовпавшего чекпоинта, или -1"
*>
fn long verify(Replay* r)
{
    Sim sim;
    sim.init(r.seed);
    Playback pb = { .replay = r };
    for (uint f = 0; f < r.frames; f++)
    {
        ushort? mask = pb.next();
        if (catch mask) return f;
        sim.step(mask);
        if (sim.frame % CHECKPOINT == 0)
        {
            if (sim.hash() != r.checkpoints[(sz)(sim.frame / CHECKPOINT) - 1]) return sim.frame;
        }
    }
    return -1;
}

// ------------------------------------------------------------ файл (готово)

const uint VERSION = 1;
excuse BAD_MAGIC, BAD_VERSION, TRUNCATED;

fn void put_u16(List{char}* out, ushort v)
{
    out.push((char)v);
    out.push((char)(v >> 8));
}

fn void put_u32(List{char}* out, uint v)
{
    put_u16(out, (ushort)v);
    put_u16(out, (ushort)(v >> 16));
}

struct Reader { char[] data; usz pos; }

fn ushort? Reader.u16(&self)
{
    if (self.pos + 2 > self.data.len) return TRUNCATED~;
    ushort v = (ushort)self.data[self.pos] | (ushort)self.data[self.pos + 1] << 8;
    self.pos += 2;
    return v;
}

fn uint? Reader.u32(&self)
{
    uint lo = self.u16()!;
    uint hi = self.u16()!;
    return lo | hi << 16;
}

fn List{char} serialize(Replay* r)
{
    List{char} out;
    foreach (c : "C3RP") out.push(c);
    put_u32(&out, VERSION);
    put_u32(&out, r.seed);
    put_u32(&out, r.frames);
    put_u32(&out, (uint)r.runs.len());
    foreach (run : r.runs)
    {
        put_u16(&out, run.mask);
        put_u16(&out, run.count);
    }
    put_u32(&out, (uint)r.checkpoints.len());
    foreach (h : r.checkpoints) put_u32(&out, h);
    return out;
}

fn Replay? deserialize(char[] data)
{
    if (data.len < 4 || (String)data[:4] != "C3RP") return BAD_MAGIC~;
    Reader rd = { data, 4 };
    if (rd.u32()! != VERSION) return BAD_VERSION~;
    Replay r;
    defer catch r.free();
    r.seed = rd.u32()!;
    r.frames = rd.u32()!;
    uint n = rd.u32()!;
    for (uint i = 0; i < n; i++) r.runs.push({ rd.u16()!, rd.u16()! });
    n = rd.u32()!;
    for (uint i = 0; i < n; i++) r.checkpoints.push(rd.u32()!);
    return r;
}

// ------------------------------------------------------------ «игрок»

// Бот, который держит случайную комбинацию действий 5..34 кадров.
struct Bot { Rng rng; ushort mask; uint left; }

fn ushort Bot.next(&self)
{
    if (self.left == 0)
    {
        self.mask = (ushort)(self.rng.next() % 16);
        self.left = 5 + self.rng.next() % 30;
    }
    self.left--;
    return self.mask;
}

fn void main()
{
    const uint SEED = 2024;
    const uint FRAMES = 600;

    // 1. Запись.
    Replay rec = { .seed = SEED };
    defer rec.free();
    Sim sim;
    sim.init(SEED);
    Bot bot = { .rng = { 99 } };
    for (uint f = 0; f < FRAMES; f++)
    {
        ushort mask = bot.next();
        rec.record_frame(mask);
        sim.step(mask);
        if (sim.frame % CHECKPOINT == 0) rec.checkpoints.push(sim.hash());
    }
    assert(rec.frames == FRAMES);
    uint total;
    foreach (run : rec.runs) total += run.count;
    assert(total == FRAMES, "RLE must cover every frame");
    io::printfn("recorded: frames=%d runs=%d checkpoints=%d score=%d final_hash=%08x",
        rec.frames, rec.runs.len(), rec.checkpoints.len(), sim.score, sim.hash());

    // 2. Сохранение и загрузка.
    List{char} bytes = serialize(&rec);
    defer bytes.free();
    file::save("replay.bin", bytes.array_view())!!;
    char[] loaded_bytes = file::load(mem, "replay.bin")!!;
    defer free(loaded_bytes);
    io::printfn("file: %d bytes (raw input would be %d bytes)", loaded_bytes.len, FRAMES * 2);
    Replay loaded = deserialize(loaded_bytes)!!;
    defer loaded.free();
    assert(loaded.runs.len() == rec.runs.len() && loaded.frames == FRAMES);

    // 3. Воспроизведение должно сойтись.
    long d = verify(&loaded);
    io::printfn("verify loaded: %d", d);
    assert(d == -1, "a clean replay must not desync");

    // 4. Подменим ввод в одном отрезке (вправо <-> влево) примерно на 300-м кадре.
    uint frame = 0;
    sz victim;
    foreach (i, run : loaded.runs)
    {
        if (frame >= 300 && run.mask & (ACT_LEFT | ACT_RIGHT) && (run.mask & (ACT_LEFT | ACT_RIGHT)) != (ACT_LEFT | ACT_RIGHT))
        {
            victim = i;
            break;
        }
        frame += run.count;
    }
    loaded.runs[victim].mask ^= ACT_LEFT | ACT_RIGHT;
    d = verify(&loaded);
    io::printfn("tampered run at frame %d: desync at %d", frame, d);
    assert(d > (long)frame && d <= (long)frame + CHECKPOINT + loaded.runs[victim].count);
    loaded.runs[victim].mask ^= ACT_LEFT | ACT_RIGHT;

    // 5. Чужой seed.
    loaded.seed = SEED + 1;
    d = verify(&loaded);
    io::printfn("wrong seed: desync at %d", d);
    assert(d == CHECKPOINT);
    loaded.seed = SEED;

    // 6. Обрезанный реплей.
    loaded.runs[^1].count -= 10;
    d = verify(&loaded);
    io::printfn("truncated input: desync at %d", d);
    assert(d == FRAMES - 10);

    // 7. Битые файлы.
    if (catch err = deserialize(loaded_bytes[:loaded_bytes.len - 3]))
    {
        assert(err == TRUNCATED);
    }
    else
    {
        unreachable("truncated file must be rejected");
    }
    if (catch err = deserialize("XXXXjunk"))
    {
        assert(err == BAD_MAGIC);
    }
    else
    {
        unreachable("bad magic must be rejected");
    }
    io::printn("corrupt files rejected");
    io::printn("replay ok");
}
