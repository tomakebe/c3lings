// Модуль gfx: публичный API текстур. Всё @private невидимо снаружи.
module gfx;

enum Format : char
{
    R8,
    RGBA8,
    DEPTH32,
}

fn int Format.bytes_per_pixel(self)
{
    switch (self)
    {
        case R8: return 1;
        case RGBA8: return 4;
        case DEPTH32: return 4;
    }
}

excuse INVALID_SIZE, MIPMAPS_NEED_POW2, OUT_OF_SLOTS, STALE_HANDLE;

// Хендл: младшие 16 бит — номер слота, старшие 16 — поколение.
typedef TextureId = uint;

const MAX_SIZE = 16384;
const SLOTS = 16;

// ---------------------------------------------------------------- внутренности

struct TextureRecord @private
{
    String name;
    int width, height;
    Format format;
    int mips;
    ushort gen;      // поколение слота (начинается с 1)
    bool alive;
}

TextureRecord[SLOTS] records @private;

fn TextureId make_id(uint slot, ushort gen) @private
{
    // TODO: упаковать: slot в младшие 16 бит, gen — в старшие
    return (TextureId)0;
}

fn uint slot_of(TextureId id)
{
    // TODO
    return 0;
}

fn ushort generation_of(TextureId id)
{
    // TODO
    return 0;
}

// Найти живую запись по хендлу или STALE_HANDLE~ (слот вне диапазона,
// слот пуст, поколение не совпало).
fn TextureRecord*? lookup(TextureId id) @private
{
    // TODO
    return STALE_HANDLE~;
}

fn int mip_chain(int w, int h) @private
{
    int n = 1;
    while (w > 1 || h > 1)
    {
        w = w > 1 ? w / 2 : 1;
        h = h > 1 ? h / 2 : 1;
        n++;
    }
    return n;
}

fn bool is_pow2(int x) @private => x > 0 && (x & (x - 1)) == 0;

// ---------------------------------------------------------------- builder

// Поля не могут называться так же, как методы (format/mipmaps) — отсюда fmt/with_mips.
struct TextureBuilder
{
    String name;
    int width, height;
    Format fmt;
    bool with_mips;
}

fn TextureBuilder texture(String name) => { .name = name, .fmt = RGBA8 };

// Каждый метод: принять копию, изменить, вернуть.
fn TextureBuilder TextureBuilder.size(self, int w, int h)
{
    // TODO
    return self;
}

fn TextureBuilder TextureBuilder.format(self, Format f)
{
    // TODO
    return self;
}

fn TextureBuilder TextureBuilder.mipmaps(self, bool on = true)
{
    // TODO
    return self;
}

fn TextureBuilder TextureBuilder.label(self, String name)
{
    // TODO
    return self;
}

fn TextureId? TextureBuilder.build(self)
{
    // TODO:
    //  * размеры в 1..MAX_SIZE, иначе INVALID_SIZE~;
    //  * mipmaps требуют обе стороны — степени двойки, иначе MIPMAPS_NEED_POW2~;
    //  * найти свободный слот (!alive), иначе OUT_OF_SLOTS~;
    //  * gen слота: если 0 — стать 1 (первое использование); destroy его увеличивает;
    //  * заполнить запись (mips = mip_chain(...) или 1), alive = true;
    //  * вернуть make_id(slot, gen).
    return OUT_OF_SLOTS~;
}

// Простой путь: именованные аргументы с умолчаниями.
fn TextureId? create_solid(String name, int w, int h, Format format = RGBA8, bool mipmaps = false)
{
    return texture(name).size(w, h).format(format).mipmaps(mipmaps).build();
}

// ---------------------------------------------------------------- запросы

fn void? destroy(TextureId id)
{
    TextureRecord* r = lookup(id)!;
    r.alive = false;
    r.gen++;
    if (r.gen == 0) r.gen = 1;     // 0 зарезервирован: переполнение поколения
}

fn String? name(TextureId id) => lookup(id)!.name;
fn int? width(TextureId id) => lookup(id)!.width;
fn int? height(TextureId id) => lookup(id)!.height;
fn int? mip_count(TextureId id) => lookup(id)!.mips;

fn sz? memory_bytes(TextureId id)
{
    TextureRecord* r = lookup(id)!;
    sz total = 0;
    int w = r.width;
    int h = r.height;
    for (int i = 0; i < r.mips; i++)
    {
        total += (sz)w * h * r.format.bytes_per_pixel();
        w = w > 1 ? w / 2 : 1;
        h = h > 1 ? h / 2 : 1;
    }
    return total;
}

fn sz live_count()
{
    sz n = 0;
    foreach (r : records) if (r.alive) n++;
    return n;
}
