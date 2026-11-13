// =====================================================================
//  089 · Атрибуты: `@align`, `@packed`, `@nodiscard`, `@noinline`…
// =====================================================================
//
//  Атрибуты — аннотации к объявлениям, которые пишутся ПОСЛЕ
//  объявляемого: `fn int f() @nodiscard`, `struct S @packed { ... }`,
//  `int x @align(16);`. Вы уже встречали `@operator`, `@dynamic`,
//  `@private`, `@local`, `@init`, `@test`. В C то же самое делается
//  нестандартными `__attribute__((packed))` / `__declspec(align(16))`,
//  разными для каждого компилятора; в C3 это часть языка.
//
//  РАСКЛАДКА ПАМЯТИ
//
//    `@packed` (struct/union) — убрать выравнивание: все поля идут
//    вплотную, без padding, выравнивание структуры = 1. Нужно для
//    двоичных форматов (заголовки файлов, сетевые пакеты), где каждый
//    байт на своём месте. Цена — невыровненный доступ к полям (на x86
//    чуть медленнее, на некоторых архитектурах — заметно). И ловушка:
//    АДРЕС невыровненного поля нельзя использовать как обычный `uint*`.
//    `io::printfn("%d", h.length)` неявно берёт адрес (аргумент
//    становится `any`), и в safe-режиме программа упадёт с
//    "Unaligned access". Копируйте поле в локальную переменную.
//
//        struct WireHeader @packed { char kind; uint length; ushort crc; }
//        // 7 байт вместо 12
//
//    `@align(N)` — минимальное выравнивание (только УВЕЛИЧИВАЕТ). На
//    структуре — для кеш-линий (64 байта: чтобы два потока не дрались за
//    одну линию, «false sharing») и SIMD (16/32); на поле — сдвигает
//    поле на границу N:
//
//        struct Counter @align(64) { int value; }    // size 64, align 64
//
//    Сочетание `@packed @align(N)` даёт «плотно внутри, но выровнено
//    снаружи».
//
//  ФУНКЦИИ
//
//    `@nodiscard` — результат нельзя игнорировать. Для функций, где
//    забытый результат почти наверняка баг (код ошибки, новое значение
//    вместо изменения на месте). Если очень надо — `(void)f();`.
//    (Optional-результаты и так нельзя молча отбросить, `@maydiscard`
//    наоборот разрешает это.)
//
//    `@inline` / `@noinline` — всегда/никогда не встраивать функцию.
//    Можно ставить и на конкретный вызов: `helper() @inline`. `@noinline`
//    полезен для «холодного» кода (обработка ошибок), чтобы не раздувать
//    горячий цикл, и для профилирования.
//
//    `@deprecated("сообщение")` — использование даёт предупреждение.
//
//    Ещё полезные: `@noreturn` (функция не возвращается — `exit`),
//    `@unused` (не предупреждать о неиспользуемом), `@cname("...")` /
//    `@export` (имя символа для C, см. 092), `@weak`, `@section(...)`.
//    Полный список — в MANUAL.md, раздел 6_13.
//
//  ЗАДАЧА:
//    1. `WireHeader` описывает 7-байтовый заголовок пакета. Добавьте
//       атрибут, чтобы проверка размера прошла.
//    2. `SharedCounter` должен занимать ровно одну кеш-линию (64 байта)
//       и быть выровнен на 64.
//    3. Поле `data` у `SimdBlock` должно начинаться со смещения 16.
//    4. Строка с `apply_damage` не компилируется из-за `@nodiscard`.
//       Это не просто так: функция НЕ меняет hp, а возвращает новое
//       значение. Исправьте вызов, чтобы результат использовался.
//
import std::io;

struct WireHeader @packed
{
    char kind;
    uint length;
    ushort crc;
}

struct SharedCounter @align(64)
{
    int value;
}

struct SimdBlock
{
    char tag;
    float[4] data @align(16);
}

fn int apply_damage(int hp, int dmg) @nodiscard
{
    return hp > dmg ? hp - dmg : 0;
}

fn int cold_path(int code) @noinline
{
    return code * 1000;
}

fn void old_api() @deprecated("use apply_damage") {}

$assert WireHeader::size == 7 : "WireHeader must be 7 bytes";
$assert SharedCounter::size == 64 && SharedCounter::alignment == 64;
$assert $reflect(SimdBlock.data).offset == 16;

fn void main()
{
    io::printfn("WireHeader:    size=%d align=%d", WireHeader::size, WireHeader::alignment);
    io::printfn("SharedCounter: size=%d align=%d", SharedCounter::size, SharedCounter::alignment);
    io::printfn("SimdBlock:     size=%d, data at offset %d", SimdBlock::size, $reflect(SimdBlock.data).offset);

    WireHeader h = { 1, 512, 0xBEEF };
    // Поля packed-структуры не выровнены. Передать их в printf напрямую
    // нельзя (он получает `any` — указатель на поле, и safe-режим
    // упадёт с "Unaligned access"). Сначала копируем в локальные
    // переменные: чтение поля по значению компилятор делает корректно.
    uint length = h.length;
    ushort crc = h.crc;
    io::printfn("header: kind=%d length=%d crc=%x", h.kind, length, crc);

    int hp = 100;
    hp = apply_damage(hp, 30);
    assert(hp == 70);
    io::printfn("hp after hit: %d", hp);

    io::printfn("cold path: %d", cold_path(7));
}
