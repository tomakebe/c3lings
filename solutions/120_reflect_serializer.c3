// =====================================================================
//  120 · Двоичный сериализатор на рефлексии
// =====================================================================
//
//  Сохранения игры, сетевые пакеты, кеш ассетов, снапшоты для
//  отката (rollback netcode), undo в редакторе — везде нужно превратить
//  структуру в байты и обратно. Писать это руками для каждой структуры
//  — скучно и опасно: добавили поле в struct, забыли в save/load — и
//  получили тихо сломанные сохранения.
//
//  ВАРИАНТЫ
//  --------
//  1. memcpy структуры целиком. Быстро, но: указатели и срезы
//     бессмысленны в файле, padding содержит мусор (утечка данных и
//     недетерминированные хеши), раскладка зависит от компилятора и
//     платформы (порядок байтов, размеры), любое изменение struct ломает
//     старые файлы.
//  2. Внешнее описание схемы + генератор кода (protobuf, FlatBuffers,
//     Cap'n Proto). Межъязыково и версионируемо, но отдельный шаг сборки.
//  3. Рефлексия во время исполнения (C#, Java). Удобно, но медленно.
//  4. Рефлексия ВО ВРЕМЯ КОМПИЛЯЦИИ: макрос обходит поля типа и
//     генерирует прямой код записи — скорость ручного кода, ноль
//     дублирования. Так работают serde в Rust (через derive), Boost.PFR,
//     reflection в Zig (`inline for (@typeInfo(T).Struct.fields)`) и
//     наш сегодняшний сериализатор.
//
//  ИНСТРУМЕНТЫ C3
//  --------------
//      var $Ty = $Typeof(value);          // тип выражения (имя — не капсом!)
//      $switch $Ty::kind:                 // TypeKind: STRUCT, ARRAY, SLICE, ENUM,
//          $case STRUCT: ...              //   FLOAT, SIGNED_INT, BOOL, TYPEDEF...
//      $endswitch
//      $foreach $m : $Ty::members:        // поля структуры
//          write_value(w, value.$m);      // доступ к полю по reflection-ссылке
//          $m.name, $m.type, $m.has_tag("transient")
//      $endforeach
//      $Ty::inner                         // тип элемента массива/среза, база typedef
//      $Typefrom($Ty::inner)              // typeid -> тип
//      bitcast(f, uint)                   // биты float как целое
//  Пользовательские теги на полях: `int cache @tag("transient", true);`
//  — поле не сохраняется (кеши, указатели, runtime-хендлы).
//  Внимание: String — это typedef над char[], его kind == TYPEDEF;
//  обрабатываем typedef, «разворачивая» его до базового типа.
//  Как и в обычном switch, ПУСТОЙ `$case X:` проваливается в следующий
//  (так объединены SIGNED_INT и UNSIGNED_INT).
//  Макрос может рекурсивно вызывать сам себя — каждый вызов
//  разворачивается для конкретного типа на этапе компиляции.
//
//  ФОРМАТ
//  ------
//  * целые и bool — little-endian, ровно Ty::size байт (явно, сдвигами,
//    а не memcpy — так формат не зависит от порядка байтов машины);
//  * float/double — их биты как uint/ulong;
//  * enum — ordinal одним байтом (при чтении — проверка диапазона!);
//  * срез/строка — uint длина (4 байта) + элементы;
//  * массив — элементы подряд (длина известна из типа);
//  * структура — поля по порядку, кроме помеченных "transient".
//  Читатель обязан не доверять данным: конец буфера, мусорный enum,
//  гигантская длина среза — это ошибка, а не падение.
//
//  Версионирование (в реальных системах): заголовок с магией и
//  версией, при чтении старой версии — миграция; или формат «тег-
//  значение» (protobuf), где неизвестные поля пропускаются.
//
//  ЗАДАЧА: допишите ветки STRUCT, ARRAY, SLICE, ENUM и FLOAT в
//  write_value и read_value. Ветки для целых, bool и typedef даны.
//
import std::io;
import std::collections::list;

excuse END_OF_DATA, BAD_ENUM, TOO_LONG;

struct Writer
{
    List{char} buf;
}

fn void Writer.put(&self, char b) => self.buf.push(b);

fn void Writer.put_uint(&self, ulong v, sz bytes)
{
    for (sz i = 0; i < bytes; i++) self.put((char)(v >> (8 * i)));
}

struct Reader
{
    char[] data;
    sz pos;
}

fn char? Reader.get(&self)
{
    if (self.pos >= self.data.len) return END_OF_DATA~;
    return self.data[self.pos++];
}

fn ulong? Reader.get_uint(&self, sz bytes)
{
    ulong v = 0;
    for (sz i = 0; i < bytes; i++) v |= (ulong)self.get()! << (8 * i);
    return v;
}

const MAX_SLICE = 1 << 20;

macro void write_value(Writer* w, value)
{
    var $Ty = $Typeof(value);
    $switch $Ty::kind:
        $case BOOL:
            w.put(value ? 1 : 0);
        $case SIGNED_INT:
        $case UNSIGNED_INT:
            $assert $Ty::size <= 8;
            w.put_uint((ulong)value, $Ty::size);
        $case TYPEDEF:
            write_value(w, ($Typefrom($Ty::inner))value);
        $case FLOAT:
            // TODO: float -> bitcast(value, uint), 4 байта; double -> ulong, 8 байт
            $if $Ty::size == 4:
                w.put_uint(bitcast(value, uint), 4);
            $else
                w.put_uint(bitcast(value, ulong), 8);
            $endif
        $case ENUM:
            // TODO: ordinal одним байтом
            $assert $Ty::len <= 256;
            w.put((char)value.ordinal);
        $case ARRAY:
            // TODO: все элементы
            foreach (x : value) write_value(w, x);
        $case SLICE:
            // TODO: длина (4 байта), затем элементы
            w.put_uint((ulong)value.len, 4);
            foreach (x : value) write_value(w, x);
        $case STRUCT:
            // TODO: поля по порядку, пропуская $m.has_tag("transient")
            $foreach $m : $Ty::members:
                $if !$m.has_tag("transient"):
                    write_value(w, value.$m);
                $endif
            $endforeach
        $default:
            $error "write_value: unsupported type " +++ $Ty::name;
    $endswitch
}

// Срезы выделяются во временном аллокаторе (читайте внутри @pool).
macro void? read_value(Reader* r, ptr)
{
    var $Ty = $Typeof(*ptr);
    $switch $Ty::kind:
        $case BOOL:
            *ptr = r.get()! != 0;
        $case SIGNED_INT:
        $case UNSIGNED_INT:
            *ptr = ($Ty)r.get_uint($Ty::size)!;
        $case TYPEDEF:
            read_value(r, ($Typefrom($Ty::inner)*)ptr)!;
        $case FLOAT:
            // TODO
            $if $Ty::size == 4:
                *ptr = bitcast((uint)r.get_uint(4)!, float);
            $else
                *ptr = bitcast(r.get_uint(8)!, double);
            $endif
        $case ENUM:
            // TODO: байт; если >= $Ty::len — BAD_ENUM~; иначе $Ty::from_ordinal
            char ord = r.get()!;
            if (ord >= $Ty::len) return BAD_ENUM~;
            *ptr = $Ty::from_ordinal(ord);
        $case ARRAY:
            // TODO
            foreach (&x : *ptr) read_value(r, x)!;
        $case SLICE:
            // TODO: длина (проверьте <= MAX_SLICE, иначе TOO_LONG~),
            //       mem::talloc_array($Typefrom($Ty::inner), len), элементы
            ulong len = r.get_uint(4)!;
            if (len > MAX_SLICE) return TOO_LONG~;
            *ptr = mem::talloc_array($Typefrom($Ty::inner), (sz)len);
            foreach (&x : *ptr) read_value(r, x)!;
        $case STRUCT:
            // TODO
            $foreach $m : $Ty::members:
                $if !$m.has_tag("transient"):
                    read_value(r, &ptr.$m)!;
                $endif
            $endforeach
        $default:
            $error "read_value: unsupported type " +++ $Ty::name;
    $endswitch
}

// ---------------------------------------------------------------- проверка

enum Class : char { WARRIOR, MAGE, ROGUE }

struct Item
{
    String name;
    short count;
}

struct Vec3i
{
    int x, y, z;
}

struct SaveGame
{
    uint version;
    String player;
    Class cls;
    bool hardcore;
    float hp;
    double play_time;
    Vec3i pos;
    Item[2] hands;
    Item[] bag;
    long gold;
    int frame_cache @tag("transient", true);   // не сохраняется
}

fn void hexdump(char[] bytes)
{
    foreach (i, b : bytes) io::printf(i ? " %02x" : "%02x", b);
    io::printn();
}

fn void main()
{
    Writer w;
    w.buf.init(mem);
    defer w.buf.free();

    // маленький пример — точные байты
    write_value(&w, (Item){ "ab", 258 });
    io::print("Item{\"ab\", 258}: ");
    hexdump(w.buf.array_view());
    char[*] expected_item = { 2, 0, 0, 0, 'a', 'b', 2, 1 };
    assert(w.buf.array_view() == &expected_item, "wrong encoding of Item");

    w.buf.clear();
    write_value(&w, (Vec3i){ -1, 0, 1 });
    write_value(&w, 1.5f);
    write_value(&w, Class.ROGUE);
    io::print("Vec3i{-1,0,1} 1.5f ROGUE: ");
    hexdump(w.buf.array_view());

    // полный круг
    Item[*] bag = { { "potion", 3 }, { "key", 1 }, { "", 0 } };
    SaveGame save = {
        .version = 7, .player = "Ada", .cls = MAGE, .hardcore = true,
        .hp = 87.25f, .play_time = 3600.5, .pos = { 10, -20, 30 },
        .hands = { { "staff", 1 }, { "orb", 1 } },
        .bag = &bag, .gold = -5_000_000_000, .frame_cache = 12345,
    };
    w.buf.clear();
    write_value(&w, save);
    char[] bytes = w.buf.array_view();
    io::printfn("SaveGame: %d bytes", bytes.len);

    @pool()
    {
        SaveGame back;
        Reader r = { bytes, 0 };
        read_value(&r, &back)!!;
        assert(r.pos == bytes.len, "reader did not consume everything");
        assert(back.version == 7 && back.player == "Ada" && back.cls == MAGE && back.hardcore);
        assert(back.hp == 87.25f && back.play_time == 3600.5);
        assert(back.pos.x == 10 && back.pos.y == -20 && back.pos.z == 30);
        assert(back.hands[1].name == "orb" && back.bag.len == 3 && back.bag[0].name == "potion" && back.bag[2].name == "");
        assert(back.gold == -5_000_000_000);
        assert(back.frame_cache == 0, "transient field must not be serialized");
        io::printfn("loaded: %s the %s, hp=%.2f, bag=%d items, gold=%d", back.player, back.cls, back.hp, back.bag.len, back.gold);

        // испорченные данные — ошибки, а не падения
        Reader trunc = { bytes[:bytes.len - 3], 0 };
        assert(@catch(read_value(&trunc, &back)) == END_OF_DATA);
        char[*] bad_enum = { 9 };
        Reader re = { &bad_enum, 0 };
        Class c;
        assert(@catch(read_value(&re, &c)) == BAD_ENUM);
        char[*] huge = { 0xFF, 0xFF, 0xFF, 0x7F };
        Reader rh = { &huge, 0 };
        String s;
        assert(@catch(read_value(&rh, &s)) == TOO_LONG);
    };
    io::printn("round trip OK");
}
