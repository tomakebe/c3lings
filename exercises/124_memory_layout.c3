// =====================================================================
//  124 · Раскладка памяти: выравнивание, padding, кеш-линии
// =====================================================================
//
//  Как поля структуры лежат в памяти — не деталь реализации, а
//  инженерный параметр: от него зависят размер массивов, число кеш-
//  промахов, совместимость с C и файловыми форматами, и даже
//  масштабируемость многопоточного кода.
//
//  ПРАВИЛА (такие же, как в C ABI на всех популярных платформах)
//  ------------------------------------------------------------
//  * У каждого типа есть выравнивание A (степень двойки): адрес значения
//    должен делиться на A. Обычно A == размер для скаляров (int — 4,
//    double — 8), у массива — как у элемента, у структуры — максимум
//    выравниваний полей.
//  * Поля кладутся В ПОРЯДКЕ ОБЪЯВЛЕНИЯ; перед полем вставляется
//    padding, чтобы его смещение делилось на его выравнивание.
//  * Размер структуры округляется вверх до её выравнивания — чтобы
//    в массиве каждый следующий элемент тоже был выровнен
//    (хвостовой padding).
//  Формула округления (A — степень двойки):
//      align_up(x, A) = (x + A - 1) & ~(A - 1)
//
//  Пример:  struct { bool a; double b; bool c; }
//      a @0, 7 байт дыры, b @8, c @16, 7 байт хвоста  => 24 байта на 10 полезных.
//  Переставим: { double b; bool a; bool c; }  => 16 байт.
//  Эвристика: сортировать поля по убыванию выравнивания. C3 (как и C)
//  НЕ переставляет поля сам — порядок важен для C-совместимости и для
//  того, чтобы вы могли управлять локальностью. Rust и Swift
//  переставляют по умолчанию.
//
//  ИНСТРУМЕНТЫ C3
//  --------------
//      Foo::size, Foo::alignment, $reflect(Foo.field).offset
//      $foreach $m : Foo::members: $m.offset, $m.type.size, $m.type.alignment
//      $assert Foo::size == 32;          // зафиксировать раскладку в коде!
//      struct Header @packed { ... }      // без padding (файлы, сеть) — но
//                                         //   невыровненный доступ медленнее/опасен
//      struct Slot @align(64) { ... }     // выравнивание (и размер) кратно 64
//
//  КЕШ-ЛИНИИ И FALSE SHARING
//  -------------------------
//  Кеш работает линиями по 64 байта (на Apple M — 128). Если два потока
//  пишут в РАЗНЫЕ переменные, лежащие в ОДНОЙ линии, ядра бесконечно
//  отбирают её друг у друга (протокол MESI) — «ложное разделение».
//  Счётчики по 8 байт подряд (`long[4]`) — классическая ловушка: код
//  корректен, но в разы медленнее. Лечение — у каждого потока свой
//  счётчик в своей линии: `struct PaddedCounter @align(64) { long value; }`.
//  Пример из жизни: Linux `____cacheline_aligned`, Java @Contended,
//  C++ std::hardware_destructive_interference_size.
//  (Время мы не печатаем — оно недетерминировано. Попробуйте сами
//  убрать @align и сравнить с `time`.)
//
//  ДРУГИЕ ПРИЁМЫ: hot/cold splitting (упр. 106), индексы uint вместо
//  указателей (упр. 114), bitstruct для флагов, `char`-перечисления.
//  Помните: структура 64 байта = ровно одна линия; 65 байт = две.
//
//  ЗАДАЧА:
//    1. Переставьте поля Fat так, чтобы выполнился $assert (32 байта).
//    2. Сделайте PaddedCounter размером в кеш-линию и Header упакованным.
//    3. Реализуйте align_up и compute_layout — ваш собственный
//       «компилятор раскладки»; main сверит его с настоящим компилятором
//       через рефлексию на нескольких структурах.
//
import std::io;
import std::thread;

const CACHE_LINE = 64;

// ---------------------------------------------------------------- 1. порядок полей

// TODO: переставьте поля (не меняя их типов и имён), чтобы размер стал 32.
struct Fat
{
    bool active;
    double x;
    char tag;
    int id;
    bool visible;
    double y;
    short kind;
}

// ---------------------------------------------------------------- 2. атрибуты

// TODO: размер и выравнивание — ровно одна кеш-линия.
struct PaddedCounter
{
    long value;
}

// Заголовок файла: ровно как на диске, без дыр. TODO: упакуйте.
struct Header
{
    char[4] magic;
    ushort version;
    uint payload_size;
    char flags;
}

// ---------------------------------------------------------------- 3. свой расчёт раскладки

fn sz align_up(sz x, sz a)
{
    assert(a > 0 && (a & (a - 1)) == 0, "alignment must be a power of two");
    // TODO
    return x;
}

struct FieldDesc
{
    sz size;
    sz align;
}

struct Layout
{
    sz[16] offsets;
    sz size;
    sz align;
}

fn Layout compute_layout(FieldDesc[] fields)
{
    assert(fields.len <= 16);
    Layout l = { .align = 1 };
    // TODO: для каждого поля: offset = align_up(текущий конец, align поля);
    //       align структуры = максимум; в конце size = align_up(конец, align).
    return l;
}

// Сверить compute_layout с компилятором для типа $Type.
macro void check_layout($Type)
{
    FieldDesc[$Type::members.len] fields;
    $foreach $i, $m : $Type::members:
        fields[$i] = { $m.type.size, $m.type.alignment };
    $endforeach
    Layout l = compute_layout(&fields);
    $foreach $i, $m : $Type::members:
        assert(l.offsets[$i] == $m.offset, "%s.%s: computed offset %d, compiler says %d",
               $Type::name, $m.name, l.offsets[$i], $m.offset);
    $endforeach
    assert(l.size == $Type::size && l.align == $Type::alignment,
           "%s: computed size %d align %d, compiler says %d / %d",
           $Type::name, l.size, l.align, $Type::size, $Type::alignment);
    io::printfn("%-8s size=%2d align=%d padding=%d", $Type::name, l.size, l.align, padding_of($Type));
}

macro sz padding_of($Type)
{
    sz used = 0;
    $foreach $m : $Type::members:
        used += $m.type.size;
    $endforeach
    return $Type::size - used;
}

struct Bad { bool a; double b; bool c; }
struct Good { double b; bool a; bool c; }
struct Vec3 { float x, y, z; }
struct Mixed { char c; Vec3 v; short s; long l; char[3] tag; }
struct Nested { short s; Mixed m; bool b; }

// ---------------------------------------------------------------- false sharing

const int THREADS = 4;
const int ITERS = 1_000_000;

fn int worker(void* arg)
{
    PaddedCounter* c = arg;
    for (int i = 0; i < ITERS; i++) c.value++;
    return 0;
}

fn void main()
{
    $assert Fat::size == 32 : "reorder the fields of Fat";
    $assert PaddedCounter::size == CACHE_LINE && PaddedCounter::alignment == CACHE_LINE : "PaddedCounter must own a cache line";
    $assert Header::size == 11 : "Header must be packed";

    assert(align_up(0, 8) == 0 && align_up(1, 8) == 8 && align_up(8, 8) == 8 && align_up(13, 4) == 16 && align_up(5, 1) == 5);

    check_layout(Bad);
    check_layout(Good);
    check_layout(Vec3);
    check_layout(Mixed);
    check_layout(Nested);
    check_layout(Fat);

    // каждый поток — в своей кеш-линии
    PaddedCounter[THREADS] counters;
    assert((usz)&counters[1] - (usz)&counters[0] == CACHE_LINE);
    Thread[THREADS] threads;
    for (int i = 0; i < THREADS; i++) threads[i].create(&worker, &counters[i])!!;
    long total = 0;
    for (int i = 0; i < THREADS; i++)
    {
        threads[i].join()!!;
        total += counters[i].value;
    }
    assert(total == (long)THREADS * ITERS);
    io::printfn("counters: %d threads x %d = %d", THREADS, ITERS, total);
    io::printfn("Header: %d bytes on disk, version at offset %d", Header::size, $reflect(Header.version).offset);
}
