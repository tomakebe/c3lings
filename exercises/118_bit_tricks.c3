// =====================================================================
//  118 · Битовые трюки: битсеты, коды Мортона
// =====================================================================
//
//  Слово процессора — это 64 булевых значения, которые обрабатываются
//  ОДНОЙ инструкцией. Битовые трюки — способ получить 64-кратный
//  параллелизм без SIMD, и они повсюду в движках и системном коде:
//  маски компонентов в ECS (archetype = битсет), видимость и
//  занятость тайлов, аллокаторы (битовая карта свободных блоков),
//  шахматные движки (bitboards), сжатые индексы БД (Roaring bitmaps),
//  пространственные индексы (коды Мортона/Z-order).
//
//  ИНСТРУМЕНТЫ (в C3 — методы целых из std::bits, компилятор
//  превращает их в одну инструкцию: popcnt, tzcnt/bsf, lzcnt/bsr):
//      x.popcount()   число единичных битов
//      x.ctz()        число нулей СПРАВА (индекс младшей единицы)
//      x.clz()        число нулей СЛЕВА
//
//  КЛАССИЧЕСКИЕ ИДИОМЫ
//  -------------------
//      x & (x - 1)        сбросить младшую единицу
//      x & (~x + 1)       выделить младшую единицу (x & -x)
//      x & (x - 1) == 0   x — степень двойки (или 0)
//      1 << (64 - (x - 1).clz())    ближайшая степень двойки >= x  (x > 1)
//
//  Обход всех единиц слова за O(число единиц), а не O(64):
//      while (w) { int bit = w.ctz(); ...; w &= w - 1; }
//
//  БИТСЕТ
//  ------
//  Массив ulong; бит i живёт в слове i >> 6 (= i / 64), позиция i & 63.
//  Пересечение/объединение множеств — по слову за раз (and/or), подсчёт
//  мощности — сумма popcount. Сравните: bool[] тратит 8 бит на элемент
//  и в 8 раз больше кеша.
//  Тонкость: «найти следующий установленный бит начиная с i» — надо
//  замаскировать в первом слове биты НИЖЕ i: `w & (~0UL << (i & 63))`.
//  Сдвиг на 64 и больше в C — UB; в C3 сдвиг на >= ширины типа
//  проверяется в safe-режиме, так что маску считаем аккуратно.
//
//  КОДЫ МОРТОНА (Z-order)
//  ----------------------
//  Перемежаем биты координат: x = x3x2x1x0, y = y3y2y1y0 ->
//  код = y3x3 y2x2 y1x1 y0x0. Точки, близкие на плоскости, получают
//  в основном близкие коды. Отсортировав объекты по коду Мортона,
//  получаем порядок, сохраняющий локальность: так строят LBVH на GPU
//  (Karras 2012), квадродеревья без указателей, раскладку текстур
//  (swizzled/tiled textures на GPU), индексы в базах геоданных.
//  Быстрое перемежение — «раздвигание» битов магическими масками:
//      v = (v | (v << 8)) & 0x00FF00FF;
//      v = (v | (v << 4)) & 0x0F0F0F0F;
//      v = (v | (v << 2)) & 0x33333333;
//      v = (v | (v << 1)) & 0x55555555;
//  (16-битное v превращается в 32-битное с нулями между битами.)
//  Обратное «сжатие» — те же маски в обратном порядке со сдвигами вправо.
//  (На x86 с BMI2 это одна инструкция pdep/pext.)
//
//  ЗАДАЧА: реализуйте функции и методы, помеченные TODO. main()
//  проверит их на решете Эратосфена, переборе и Z-order сортировке.
//
import std::io;
import std::sort;

// ---------------------------------------------------------------- одиночные слова

fn bool is_pow2(ulong x)
{
    // TODO
    return false;
}

fn ulong next_pow2(ulong x)
{
    // TODO: 0 и 1 -> 1; иначе через clz.
    return x;
}

fn ulong lowest_bit(ulong x)
{
    // TODO
    return 0;
}

// ---------------------------------------------------------------- битсет

struct Bitset
{
    ulong[] words;
    sz bits;
}

fn void Bitset.init(&self, sz bits)
{
    self.bits = bits;
    self.words = mem::new_array(ulong, (bits + 63) / 64);
}

fn void Bitset.free(&self) => free(self.words);

fn void Bitset.set(&self, sz i)
{
    // TODO
}

fn void Bitset.reset(&self, sz i)
{
    // TODO
}

fn bool Bitset.test(&self, sz i)
{
    // TODO
    return false;
}

fn sz Bitset.count(&self)
{
    // TODO: сумма popcount по словам
    return 0;
}

// Индекс первого установленного бита >= from, или -1.
fn sz Bitset.next_set(&self, sz from)
{
    // TODO: замаскировать младшие биты первого слова, дальше — первое ненулевое слово + ctz.
    return -1;
}

// Обход всех установленных битов: @each_set(&bs; sz i) { ... };
macro @each_set(Bitset* bs; @body(sz idx))
{
    // TODO: по словам; внутри — while (w) { ctz; @body; w &= w - 1; }
}

// ---------------------------------------------------------------- Мортон

fn uint part1by1(uint v)
{
    // TODO: раздвинуть 16 младших битов (маски из шапки)
    return v;
}

fn uint compact1by1(uint v)
{
    // TODO: обратная операция
    return v;
}

fn uint morton_encode(uint x, uint y) => part1by1(x) | (part1by1(y) << 1);
fn uint morton_x(uint code) => compact1by1(code);
fn uint morton_y(uint code) => compact1by1(code >> 1);

// ---------------------------------------------------------------- проверка

struct Pt
{
    uint x, y;
    uint code;
}

fn void main()
{
    assert(is_pow2(1) && is_pow2(64) && is_pow2(1UL << 63) && !is_pow2(0) && !is_pow2(96));
    assert(next_pow2(0) == 1 && next_pow2(1) == 1 && next_pow2(5) == 8 && next_pow2(64) == 64 && next_pow2(65) == 128);
    assert(lowest_bit(0b101000) == 0b1000 && lowest_bit(0) == 0);

    // решето Эратосфена на битсете
    const sz N = 100_000;
    Bitset composite;
    composite.init(N);
    defer composite.free();
    composite.set(0);
    composite.set(1);
    for (sz p = 2; p * p < N; p++)
    {
        if (composite.test(p)) continue;
        for (sz m = p * p; m < N; m += p) composite.set(m);
    }
    sz primes = N - composite.count();
    assert(primes == 9592, "primes below 100000: %d", primes);
    assert(!composite.test(99991) && composite.test(99999));
    composite.reset(99999);
    assert(!composite.test(99999));
    composite.set(99999);

    // next_set и @each_set на маленьком множестве
    Bitset s;
    s.init(200);
    defer s.free();
    sz[*] members = { 0, 3, 63, 64, 65, 127, 128, 199 };
    foreach (m : members) s.set(m);
    sz k = 0;
    for (sz i = s.next_set(0); i != -1; i = s.next_set(i + 1)) assert(i == members[k++], "next_set order");
    assert(k == members.len);
    assert(s.next_set(66) == 127 && s.next_set(129) == 199 && s.next_set(200) == -1);
    sz sum = 0;
    sz seen = 0;
    @each_set(&s; sz i) { sum += i; seen++; };
    assert(seen == members.len && sum == 0 + 3 + 63 + 64 + 65 + 127 + 128 + 199, "@each_set");
    io::printfn("primes < %d: %d, set {..}: count=%d sum=%d", N, primes, s.count(), sum);

    // Мортон: полный перебор 256x256 туда-обратно
    for (uint y = 0; y < 256; y++)
    {
        for (uint x = 0; x < 256; x++)
        {
            uint c = morton_encode(x, y);
            assert(morton_x(c) == x && morton_y(c) == y, "morton round trip %d,%d", x, y);
        }
    }
    assert(morton_encode(0xFFFF, 0) == 0x55555555 && morton_encode(0, 0xFFFF) == 0xAAAAAAAA);

    // Z-order обход сетки 4x4
    Pt[16] pts;
    for (uint i = 0; i < 16; i++) pts[i] = { i % 4, i / 4, morton_encode(i % 4, i / 4) };
    sort::quicksort(&pts, fn int(Pt a, Pt b) => (int)a.code - (int)b.code);
    io::print("z-order 4x4:");
    foreach (p : pts) io::printf(" (%d,%d)", p.x, p.y);
    io::printn();
}
