// =====================================================================
//  E0203 · Двусторонний стековый аллокатор с маркерами
// =====================================================================
//
//  Сначала прочитайте engine/docs/02_memory.md (раздел 5).
//
//  Стековый аллокатор — арена, которая умеет откатываться к сохранённой
//  позиции (маркеру). Освобождение строго LIFO — идеально для вложенных
//  времён жизни: игра ⊃ уровень ⊃ секция уровня ⊃ временные данные.
//
//  Двусторонний вариант растёт с ДВУХ концов одного буфера:
//
//      0                                                       len
//      [LLLLLLLLLLLL lo->  ....свободно....   <-hi TTTTTTTTTTT]
//       нижний стек: долгоживущее        верхний стек: временное
//
//  Нижний стек хранит данные уровня, верхний — временные буферы загрузки
//  (распаковка, парсинг). Им не нужно делить буфер заранее: память общая.
//
//  Верхний стек растёт вниз: новый блок начинается по адресу
//  align_down(base + hi - size, align), и это должно быть >= base + lo.
//  align_down(x, a) = x & ~(a - 1).
//
//  Маркер — это просто сохранённое значение lo (или hi). free_to_*
//  откатывает стек к маркеру. Маркер недействителен, если стек уже
//  откатили НИЖЕ него (для нижнего стека: m.value > lo; для верхнего:
//  m.value < hi) или если это маркер другой стороны. В этом случае
//  free_to_* возвращает false и ничего не меняет — в настоящем движке
//  здесь был бы assert в отладочной сборке.
//
//  ЗАДАЧА: реализуйте alloc_lo, alloc_hi, free_to_lo, free_to_hi.
//
import std::io;

fn usz align_up(usz x, usz a) => (x + a - 1) & ~(a - 1);
fn usz align_down(usz x, usz a) => x & ~(a - 1);

enum Side { LOW, HIGH }

struct Marker
{
    Side side;
    usz value;
}

struct DoubleStack
{
    char[] buf;
    usz lo;      // первый свободный байт снизу
    usz hi;      // начало занятой области сверху (== len, если пусто)
}

fn void DoubleStack.init(&self, char[] buf)
{
    self.buf = buf;
    self.lo = 0;
    self.hi = (usz)buf.len;
}

fn usz DoubleStack.free_bytes(&self) => self.hi - self.lo;

fn void* DoubleStack.alloc_lo(&self, usz size, usz align)
{
    // TODO: как арена из E0202, но верхняя граница — self.hi, а не len
    return null;
}

fn void* DoubleStack.alloc_hi(&self, usz size, usz align)
{
    // TODO: блок начинается с align_down(base + hi - size, align) - base;
    //       он не должен опуститься ниже lo (и не забудьте про size > hi - lo)
    return null;
}

fn Marker DoubleStack.mark_lo(&self) => { LOW, self.lo };
fn Marker DoubleStack.mark_hi(&self) => { HIGH, self.hi };

fn bool DoubleStack.free_to_lo(&self, Marker m)
{
    // TODO: проверить сторону и что маркер не выше текущей вершины
    self.lo = m.value;
    return true;
}

fn bool DoubleStack.free_to_hi(&self, Marker m)
{
    // TODO
    self.hi = m.value;
    return true;
}

fn void report(String what, DoubleStack* s)
{
    io::printfn("%-22s lo=%4d hi=%4d free=%4d", what, s.lo, s.hi, s.free_bytes());
}

struct Mesh { float[<3>][32] verts; }    // 384 байта

fn void main()
{
    char[2048] storage @align(64);
    DoubleStack s;
    s.init(&storage);
    report("start", &s);

    // Данные игры — навсегда, внизу.
    Marker game = s.mark_lo();
    assert(s.alloc_lo(100, 8) != null);
    report("game data", &s);

    // Загрузка уровня: статика внизу, временный буфер распаковки сверху.
    Marker level = s.mark_lo();
    Marker load_tmp = s.mark_hi();
    char* unpack = s.alloc_hi(700, 16);
    assert(unpack != null && ((usz)unpack & 15) == 0, "high allocation must be aligned");
    assert((usz)(unpack - (char*)&storage) == 2048 - 704, "high stack grows down: 2048-700 aligned down to 16");
    Mesh* m1 = s.alloc_lo(Mesh::size, Mesh::alignment);
    Mesh* m2 = s.alloc_lo(Mesh::size, Mesh::alignment);
    assert(m1 && m2 && (char*)m2 - (char*)m1 == Mesh::size);
    report("level + unpack buffer", &s);

    // Места на ещё один меш снизу уже нет — стороны встретились бы.
    assert(s.alloc_lo(Mesh::size * 2, 4) == null, "low stack must not run into the high stack");
    assert(s.alloc_hi(s.free_bytes() + 1, 1) == null, "high stack must not run into the low stack");

    // Загрузка завершена: временный буфер освобождаем — место вернулось.
    assert(s.free_to_hi(load_tmp));
    report("unpack freed", &s);
    assert(s.alloc_lo(Mesh::size * 2, 4) != null, "now there is room");
    report("more level data", &s);

    // Секция уровня с вложенным маркером.
    Marker section = s.mark_lo();
    s.alloc_lo(50, 1);
    s.alloc_lo(50, 1);
    assert(s.free_to_lo(section));

    // Выгрузка уровня. После неё маркер section недействителен.
    assert(s.free_to_lo(level));
    report("level unloaded", &s);
    assert(!s.free_to_lo(section), "stale marker (above current top) must be rejected");
    assert(!s.free_to_hi(level), "low marker must not be accepted by the high stack");
    assert(!s.free_to_lo(load_tmp), "high marker must not be accepted by the low stack");
    assert(s.lo == 100 && s.hi == 2048, "rejected markers must not change anything");

    assert(s.free_to_lo(game));
    report("all freed", &s);
    assert(s.free_bytes() == 2048);
    io::printn("double-ended stack OK");
}
