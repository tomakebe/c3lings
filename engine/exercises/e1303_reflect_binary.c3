// =====================================================================
//  e1303 · Бинарный сериализатор на compile-time рефлексии
// =====================================================================
//
//  Сначала прочитайте engine/docs/13_serialization.md (раздел 13.7).
//
//  Писать save/load руками для сотен структур — путь к багам: добавили
//  поле, забыли дописать в load — и сохранения молча едут. Поэтому движки
//  генерируют сериализацию из описания типа (UPROPERTY в Unreal,
//  [SerializeField] в Unity). В C3 рефлексия встроена в язык:
//
//      $foreach $f : $Typeof(x)::members:     // список полей, compile-time
//          $f.name            // "hp"
//          $f.type            // typeid поля (сравнивается в $switch / $if)
//          $f.type.kind       // STRUCT, ARRAY, SIGNED_INT, ...
//          $f.has_tag("since") / $f.get_tag("since")   // наши метаданные
//          x.$eval($f.name)   // само поле — обычный доступ, без строк в рантайме
//      $endforeach
//
//  Метаданные на полях задаются атрибутом `@tag(имя, значение)`:
//      ushort level @tag("since", 2);        // поле появилось в версии 2
//      int    cache @tag("transient", true); // не сохранять вовсе
//
//  Макрос разворачивается в прямолинейный код для каждого типа: это ровно
//  то, что вы написали бы руками, только без ошибок и без поддержки.
//  Обратите внимание, что макросы рекурсивны: для вложенной структуры
//  `@save` вызывает сам себя с полем, и компилятор разворачивает дальше.
//
//  Правила формата (версия SCHEMA_VERSION = 3):
//    * поля пишутся в порядке объявления, transient — пропускаются;
//    * int/uint — 4 байта LE, ushort — 2, bool — 1 (0/1), float — 4 (bitcast);
//    * массив фиксированной длины — элементы подряд, структура — поля подряд;
//    * при ЧТЕНИИ файла версии V поле с @tag("since", N), где N > V,
//      в файле отсутствует — его НЕ читаем, оставляем значение по умолчанию;
//    * bool со значением, отличным от 0 и 1, — ошибка CORRUPT.
//
//  @save уже написан. Его зеркало @load — ваша задача.
//
//  ЗАДАЧА: реализуйте макрос @load (место с TODO). Он должен проходить
//  «золотые» байты версий 1 и 2, записанные старыми билдами игры.
//
import std::io;

excuse END_OF_DATA, CORRUPT;

const ushort SCHEMA_VERSION = 3;

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

// ------------------------------------------------------------ игровые данные

struct Vec2
{
    float x;
    float y;
}

struct Stats
{
    ushort strength;
    ushort agility;
}

struct Player
{
    int id;
    Vec2 pos;
    Vec2 vel @tag("transient", true);       // пересчитывается физикой
    int hp;
    bool[3] keys;
    Stats stats @tag("since", 2);
    uint gold @tag("since", 3);
    float path_cost @tag("transient", true); // кэш навигации
}

const Player DEFAULT_PLAYER = {
    .hp = 100,
    .stats = { 5, 5 },
    .gold = 10,
    .path_cost = -1,
};

// ------------------------------------------------------------ сериализатор

macro void @save(ByteWriter* w, x)
{
    $switch $Typeof(x):
        $case int:    w.u32((uint)x);
        $case uint:   w.u32(x);
        $case ushort: w.u16(x);
        $case float:  w.u32(bitcast(x, uint));
        $case bool:   w.u8(x ? 1 : 0);
        $default:
            $if $Typeof(x)::kind == ARRAY:
                foreach (e : x) @save(w, e);
            $else
                $foreach $f : $Typeof(x)::members:
                    $if !$f.has_tag("transient"):
                        @save(w, x.$eval($f.name));
                    $endif
                $endforeach
            $endif
    $endswitch
}

// Читает в *ptr данные, записанные схемой версии `version`.
macro void? @load(ByteReader* r, ushort version, ptr)
{
    // TODO: зеркало @save, но:
    //   * пишем в *ptr (`*ptr = ...`, поля — `ptr.$eval($f.name)`,
    //     рекурсивный вызов — `@load(r, version, &ptr.$eval($f.name))!;`);
    //   * для массива: `foreach (&e : *ptr) @load(r, version, e)!;`;
    //   * поле с тегом "since" > version пропускаем (значение по умолчанию остаётся),
    //     transient — пропускаем всегда;
    //   * bool: байт 0 -> false, 1 -> true, иначе CORRUPT~;
    //   * ошибки чтения пробрасываем `!`.
    return;
}

// ------------------------------------------------------------ утилиты

macro void print_schema($Type)
{
    io::printf("%s v%d:", $Type::name, SCHEMA_VERSION);
    $foreach $f : $Type::members:
        io::printf(" %s:%s", $f.name, $f.type.name);
        $if $f.has_tag("since"):
            io::printf("(since %d)", $f.get_tag("since"));
        $endif
        $if $f.has_tag("transient"):
            io::print("(transient)");
        $endif
    $endforeach
    io::printn();
}

fn void hexdump(char[] bytes)
{
    foreach (i, b : bytes)
    {
        io::printf("%02x", b);
        io::print((i % 16 == 15 || i + 1 == bytes.len) ? "\n" : " ");
    }
}

fn void print_player(String label, Player* p)
{
    io::printfn("%s: id=%d pos=(%.2f, %.2f) hp=%d keys=%s/%s/%s str=%d agi=%d gold=%d",
        label, p.id, p.pos.x, p.pos.y, p.hp, p.keys[0], p.keys[1], p.keys[2],
        p.stats.strength, p.stats.agility, p.gold);
}

fn Player? load_player(char[] bytes, ushort version)
{
    ByteReader r = { .data = bytes };
    Player p = DEFAULT_PLAYER;
    @load(&r, version, &p)!;
    if (r.pos != bytes.len) return CORRUPT~;   // лишние байты — тоже порча
    return p;
}

// «Золотые» файлы: байты, записанные билдами версий 1 и 2.
// v1: id, pos, hp, keys
const char[] GOLDEN_V1 = {
    0x07, 0x00, 0x00, 0x00,  0x00, 0x00, 0x20, 0x41,  0x00, 0x00, 0xa0, 0xc0,
    0x2a, 0x00, 0x00, 0x00,  0x01, 0x00, 0x01,
};
// v2: + stats
const char[] GOLDEN_V2 = {
    0x08, 0x00, 0x00, 0x00,  0x00, 0x00, 0x80, 0x3f,  0x00, 0x00, 0x00, 0x40,
    0x63, 0x00, 0x00, 0x00,  0x00, 0x01, 0x00,  0x0c, 0x00, 0x03, 0x00,
};

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
    print_schema(Player);

    // --- круговой тест текущей версии ---
    Player p = DEFAULT_PLAYER;
    p.id = 3;
    p.pos = { 1.5, -2.25 };
    p.vel = { 9, 9 };
    p.hp = 77;
    p.keys = { true, false, true };
    p.stats = { 14, 8 };
    p.gold = 1234;
    p.path_cost = 55;

    ByteWriter w;
    @save(&w, p);
    io::printfn("v3 bytes: %d", w.len);
    hexdump(w.bytes());

    Player q = load_player(w.bytes(), SCHEMA_VERSION)!!;
    assert(q.id == 3 && q.hp == 77 && q.pos.x == 1.5f && q.pos.y == -2.25f);
    assert(q.keys[0] && !q.keys[1] && q.keys[2]);
    assert(q.stats.strength == 14 && q.stats.agility == 8 && q.gold == 1234);
    assert(q.vel.x == 0 && q.path_cost == -1, "transient fields keep defaults");
    print_player("v3", &q);

    // --- старые сохранения ---
    Player a = load_player(GOLDEN_V1, 1)!!;
    assert(a.id == 7 && a.hp == 42 && a.pos.x == 10 && a.pos.y == -5);
    assert(a.stats.strength == 5 && a.gold == 10, "fields newer than the file keep defaults");
    print_player("v1", &a);

    Player b = load_player(GOLDEN_V2, 2)!!;
    assert(b.id == 8 && b.hp == 99 && b.stats.strength == 12 && b.stats.agility == 3);
    assert(b.gold == 10);
    print_player("v2", &b);

    // --- порча ---
    @expect_err("v2 bytes read as v3", load_player(GOLDEN_V2, 3));
    @expect_err("v2 bytes read as v1", load_player(GOLDEN_V2, 1));
    char[64] evil;
    evil[:GOLDEN_V1.len] = GOLDEN_V1[..];
    evil[17] = 7;   // keys[1] = 7 ?!
    @expect_err("bad bool", load_player(evil[:GOLDEN_V1.len], 1));

    io::printn("reflection serializer ok");
}
