// =====================================================================
//  e0701 · Пути, хеши и ResourceId
// =====================================================================
//
//  Сначала прочитайте engine/docs/07_resources.md (разделы
//  «Идентификация ресурса» и «Коллизии»).
//
//  Движок почти никогда не хранит и не сравнивает строки путей во время
//  игры. Вместо "textures/hero.png" он оперирует 64-битным числом —
//  ResourceId = FNV-1a(канонический путь). Сравнение — одна инструкция,
//  ключ хеш-таблицы — 8 байт, а сама строка нужна только в отладке.
//
//  Но у хеширования путей есть две ловушки:
//
//  1. Один и тот же файл можно записать по-разному:
//         "Textures\\Hero.PNG", "./textures//hero.png",
//         "textures/old/../hero.png"
//     Если хешировать как есть — получим ТРИ разных id для одного ассета
//     и загрузим его трижды. Поэтому перед хешированием путь приводят к
//     каноническому виду: '\' -> '/', нижний регистр, пустые сегменты и
//     "." выбрасываются, ".." удаляет предыдущий сегмент.
//
//  2. Коллизии. Разные пути могут дать один хеш. Для 64 бит это крайне
//     маловероятно, но не невозможно, и узнать об этом нужно в ИНСТРУМЕНТАХ
//     (при регистрации/сборке), а не по странному багу в релизе. Поэтому
//     в debug-сборках держат реестр id -> путь и проверяют каждое
//     добавление.
//
//  FNV-1a (64 бит):
//      h = 0xcbf29ce484222325
//      для каждого байта c:  h = (h ^ c) * 0x100000001b3
//  (умножение по модулю 2^64 — в C3 беззнаковое переполнение просто
//  «заворачивается», как в C).
//
//  Хеш строкового литерала можно посчитать во время компиляции макросом
//  с `$for` — тогда `@rid("sounds/jump.wav")` — это просто константа,
//  и её можно использовать даже в `case` у `switch`.
//
//  ЗАДАЧА (места помечены TODO):
//    1. fnv1a64(data) — runtime-хеш.
//    2. @rid($path) — тот же хеш во время компиляции (через $for).
//    3. normalize_path(path, out) — каноникализация по правилам выше.
//    4. Registry.register(path) — нормализовать, хешировать и поймать
//       коллизию: тот же id, но ДРУГОЙ канонический путь -> ID_COLLISION~.
//
import std::io;
import std::collections::map;

const ulong FNV_OFFSET = 0xcbf29ce484222325;
const ulong FNV_PRIME = 0x100000001b3;

typedef ResourceId = ulong;

excuse ID_COLLISION, PATH_TOO_LONG;

fn ulong fnv1a64(char[] data)
{
    // TODO: FNV-1a 64: начать с FNV_OFFSET, для каждого байта h = (h ^ c) * FNV_PRIME
    return 0;
}

// Хеш во время компиляции. Литерал должен быть УЖЕ каноническим.
macro ulong @rid(String $path) @const
{
    // TODO: то же самое, но compile-time: `var $h = ...;` и `$for ... $endfor`.
    //       Единственная runtime-инструкция макроса — `return $h;`.
    return 0ul;
}

<*
 Пишет канонический путь в out и возвращает срез out.
 Правила: '\' -> '/', A-Z -> a-z, пустые и "." сегменты пропускаются,
 ".." удаляет предыдущий сегмент (если он есть), сегменты соединяются '/'.
*>
fn String? normalize_path(String path, char[] out)
{
    // TODO: разбейте path на сегменты по '/' и '\\', пропустите пустые и ".",
    //       на ".." откатите n до предыдущего '/', остальные сегменты
    //       допишите в out через '/' в нижнем регистре.
    //       Если не помещается в out -> return PATH_TOO_LONG~;
    if (path.len > out.len) return PATH_TOO_LONG~;
    out[:path.len] = path[..];
    return (String)out[:path.len];
}

fn ResourceId? path_id(String path)
{
    char[256] buf;
    String norm = normalize_path(path, &buf)!;
    return (ResourceId)fnv1a64(norm);
}

// ---------------------------------------------------------------------
// Реестр id -> канонический путь (живёт в инструментах / debug-сборке).
// hash_bits позволяет искусственно «обрезать» хеш, чтобы увидеть
// коллизии своими глазами.
// ---------------------------------------------------------------------
struct Registry
{
    HashMap{ulong, String} names;   // владеет копиями строк
    ulong mask;
}

fn void Registry.init(&self, int hash_bits)
{
    self.names.init(mem);
    self.mask = hash_bits >= 64 ? ulong::max : (1ul << hash_bits) - 1;
}

fn void Registry.free(&self)
{
    self.names.@each(; ulong k, String v) { v.free(mem); };
    self.names.free();
}

fn ResourceId? Registry.register(&self, String path)
{
    char[256] buf;
    String norm = normalize_path(path, &buf)!;
    ulong id = fnv1a64(norm) & self.mask;
    // TODO: если id уже есть в self.names:
    //         - тот же канонический путь -> просто вернуть id;
    //         - другой путь -> ID_COLLISION~.
    //       Иначе сохранить КОПИЮ строки (norm.copy(mem)) — buf умрёт
    //       при выходе из функции.
    return (ResourceId)id;
}

fn void main()
{
    // --- 1. runtime FNV-1a ---
    assert(fnv1a64("") == FNV_OFFSET, "empty string must hash to the offset basis");
    assert(fnv1a64("a") == 0xaf63dc4c8601ec8c, "fnv1a64(\"a\") is wrong");
    io::printfn("fnv(\"textures/hero.png\") = %x", fnv1a64("textures/hero.png"));

    // --- 2. compile-time id ---
    ulong jump = @rid("sounds/jump.wav");   // (assert на const проверяется при компиляции)
    assert(jump == fnv1a64("sounds/jump.wav"), "@rid must equal the runtime hash");
    assert(jump != 0, "@rid is not implemented");
    switch (fnv1a64("sounds/jump.wav"))
    {
        case @rid("sounds/jump.wav"): io::printn("switch on compile-time id: ok");
        default: unreachable("switch on @rid failed");
    }

    // --- 3. normalization ---
    char[256] buf;
    String[*] variants = {
        "textures/hero.png",
        "Textures\\Hero.PNG",
        "./textures//hero.png",
        "/textures/old/../hero.png",
        "textures/./a/b/../../hero.png",
    };
    foreach (v : variants)
    {
        String n = normalize_path(v, &buf)!!;
        io::printfn("%-32s -> %s", v, n);
        assert(n == "textures/hero.png", "bad normalization of '%s': '%s'", v, n);
        assert(path_id(v)!! == (ResourceId)fnv1a64("textures/hero.png"));
    }
    assert(normalize_path("../../x", &buf)!! == "x");
    assert(normalize_path("", &buf)!! == "");
    char[4] tiny;
    assert(@catch(normalize_path("models/tree.mesh", &tiny)) == PATH_TOO_LONG,
           "overflow of the output buffer must be reported");

    // --- 4. registry with full 64-bit ids: no collisions expected ---
    Registry full;
    full.init(64);
    defer full.free();
    ResourceId a = full.register("textures/hero.png")!!;
    ResourceId b = full.register("TEXTURES\\hero.png")!!;   // same asset
    assert(a == b, "same asset must give the same id");
    assert(full.names.len() == 1);

    // --- 5. registry with 16-bit ids: birthday paradox in action ---
    Registry small;
    small.init(16);
    defer small.free();
    int collisions = 0;
    for (int i = 0; i < 1000; i++)
    {
        String p = string::tformat("levels/l%d/asset_%d.tex", i % 7, i);
        if (catch err = small.register(p))
        {
            assert(err == ID_COLLISION);
            collisions++;
        }
    }
    io::printfn("16-bit ids, 1000 paths: %d collisions", collisions);
    assert(collisions > 0, "with 16-bit ids collisions are expected - register must detect them");
    io::printn("all path/hash tests passed");
}
