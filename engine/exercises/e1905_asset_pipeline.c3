// =====================================================================
//  e1905 · Инкрементальный пайплайн ассетов
// =====================================================================
//
//  Исходные ассеты (PSD, FBX, WAV, .shader) редактор не грузит в игру
//  как есть: их «варят» (cook) в формат рантайма — сжатые текстуры,
//  оптимизированные меши, скомпилированные шейдеры. Полная варка
//  AAA-проекта занимает часы, поэтому пайплайн ОБЯЗАН быть
//  инкрементальным: пересобирать только то, что действительно изменилось.
//
//  Ассеты образуют граф зависимостей:
//
//      rock.png --+
//                 +--> rock.mat --+
//      lit.shader-+               +--> rock.model
//      rock.fbx ------------------+
//
//  Ключ кэша (как в Bazel, Unreal DDC, Bitsquid data compiler):
//
//      key = hash( версия_билдера_типа,
//                  содержимое_исходника,
//                  ВЫХОДНЫЕ хеши всех зависимостей )
//
//  Если ключ совпал с тем, что лежит в кэше, — результат берём из
//  кэша. Почему не время модификации файла: git checkout, копирование
//  и сетевые диски ломают время; хеш содержимого — нет. Почему версия
//  билдера: поменяли код компрессора текстур — все текстуры устарели,
//  хотя ни один исходник не менялся.
//
//  Тонкость «раннего отсечения» (early cutoff): зависимые ассеты
//  ключуются ВЫХОДНЫМ хешем зависимости, а не входным. Если правка
//  исходника не изменила результат (поправили комментарий в шейдере),
//  зависимые НЕ пересобираются.
//
//  ЗАДАЧА: реализуйте compute_key и Pipeline.build (рекурсивно:
//  сначала зависимости, затем сам ассет; каждый ассет — не больше
//  одного раза за проход).
//
import std::io;

const int MAX_ASSETS = 8;

enum AssetType : char
{
    TEXTURE,
    SHADER,
    MESH,
    MATERIAL,
    MODEL,
}

// Версии билдеров по типам: увеличьте — и все ассеты типа устареют.
uint[AssetType::len] g_builder_version = { 3, 1, 2, 1, 1 };

struct Asset
{
    String name;
    AssetType type;
    String source;
    int[3] deps;
    int dep_count;
    // кэш (как будто лежит на диске)
    uint cached_key;
    uint output_hash;
    bool has_cache;
}

struct Pipeline
{
    Asset[MAX_ASSETS] assets;
    int count;
    bool[MAX_ASSETS] visited;    // за текущий проход
    int cooked;
}

fn uint fnv(uint h, char[] data)
{
    foreach (b : data) h = (h ^ b) * 16777619;
    return h;
}

fn uint fnv_u32(uint h, uint v)
{
    for (int i = 0; i < 4; i++) h = (h ^ ((v >> (8 * i)) & 0xFF)) * 16777619;
    return h;
}

// «Варка»: результат зависит от билдера, зависимостей и исходника, но
// комментарии ('#' до конца строки) в выход не попадают — отсюда
// раннее отсечение.
fn uint cook(Asset* a, uint deps_hash)
{
    uint h = fnv_u32(2166136261, g_builder_version[a.type]);
    h = fnv_u32(h, deps_hash);
    bool comment = false;
    foreach (c : a.source)
    {
        if (c == '#') comment = true;
        if (c == '\n') comment = false;
        if (!comment) h = (h ^ c) * 16777619;
    }
    return h;
}

fn int Pipeline.add(&self, String name, AssetType type, String source, int[] deps = {})
{
    Asset* a = &self.assets[self.count];
    *a = { .name = name, .type = type, .source = source, .dep_count = (int)deps.len };
    foreach (i, d : deps) a.deps[i] = d;
    return self.count++;
}

// Хеш выходов зависимостей (по порядку deps).
fn uint Pipeline.deps_hash(&self, Asset* a)
{
    uint h = 2166136261;
    for (int i = 0; i < a.dep_count; i++) h = fnv_u32(h, self.assets[a.deps[i]].output_hash);
    return h;
}

// key = hash(версия билдера, исходник, deps_hash)
fn uint compute_key(Asset* a, uint deps_hash)
{
    // TODO: версия билдера + содержимое + deps_hash
    (void)deps_hash;
    return fnv(2166136261, a.source);
}

fn void Pipeline.build(&self, int i)
{
    // TODO: visited; зависимости; ключ; при промахе кэша — cook, обновить
    // кэш, cooked++ и напечатать имя: io::printf(" %s", a.name);
    (void)i;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

fn void Pipeline.build_all(&self, String title)
{
    self.visited = {};
    self.cooked = 0;
    io::printf("%-22s cooked:", title);
    for (int i = 0; i < self.count; i++) self.build(i);
    if (self.cooked == 0) io::printf(" (nothing)");
    io::printn();
}

fn void main()
{
    Pipeline p;
    int png = p.add("rock.png", TEXTURE, "pixels-v1");
    int shader = p.add("lit.shader", SHADER, "color = albedo * light; # basic\n");
    int fbx = p.add("rock.fbx", MESH, "verts-v1");
    int mat = p.add("rock.mat", MATERIAL, "roughness=0.8", { png, shader });
    p.add("rock.model", MODEL, "lod=2", { fbx, mat });
    int grass = p.add("grass.png", TEXTURE, "green");
    p.add("grass.mat", MATERIAL, "roughness=1.0", { grass, shader });

    p.build_all("initial build");
    assert(p.cooked == 7);
    p.build_all("no changes");
    assert(p.cooked == 0, "без изменений ничего не варится");

    p.assets[png].source = "pixels-v2";
    p.build_all("edit rock.png");
    assert(p.cooked == 3, "png -> mat -> model");

    p.assets[shader].source = "color = albedo * light; # tweaked comment\n";
    p.build_all("edit shader comment");
    assert(p.cooked == 1, "раннее отсечение: зависимые не пересобираются");

    p.assets[shader].source = "color = albedo * light * ao;\n";
    p.build_all("edit shader code");
    assert(p.cooked == 4);

    g_builder_version[AssetType.TEXTURE]++;
    p.build_all("texture builder v4");
    assert(p.cooked == 5, "все текстуры и всё, что от них зависит");
}
