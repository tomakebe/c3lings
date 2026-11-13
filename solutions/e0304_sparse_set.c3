// =====================================================================
//  E0304 · Sparse set с пагинацией
// =====================================================================
//
//  Сначала прочитайте engine/docs/03_containers.md (раздел 5).
//
//  Sparse set хранит множество id (например, сущностей) так, что
//  add/remove/contains — O(1), а обход — по плотному массиву:
//
//      sparse[id] -> позиция в dense      dense[pos] -> id
//      contains(id):  sparse[id] != EMPTY  (и dense[sparse[id]] == id)
//
//  Пагинация: id бывают до 65535, а в множестве может быть 10 элементов.
//  Держать sparse на 65536 элементов для каждого типа компонента —
//  расточительно. Поэтому sparse разбит на страницы по PAGE_SIZE
//  элементов, и страница выделяется только при первой записи в неё
//  (заполненная EMPTY). contains() по id из невыделенной страницы
//  просто возвращает false — ничего не выделяя!
//
//      id = 1234:   page = 1234 / 256 = 4,  offset = 1234 % 256 = 210
//
//  Пересечение (запрос «все сущности, у которых есть A и B и C»):
//  обходим САМОЕ МАЛЕНЬКОЕ множество и проверяем contains в остальных.
//  Счётчик probes в main проверяет, что вы действительно так сделали.
//
//  ЗАДАЧА: реализуйте SparseSet.sparse_get, SparseSet.sparse_ref
//  (с ленивым выделением страницы), add, remove и функцию intersect.
//
import std::io, std::collections::list;

const uint PAGE_SIZE = 256;
const uint MAX_ID = 65536;
const uint MAX_PAGES = MAX_ID / PAGE_SIZE;
const uint EMPTY = uint::max;

struct SparseSet
{
    Allocator alloc;
    uint*[MAX_PAGES] pages;
    List{uint} dense;
    int pages_allocated;
}

fn void SparseSet.init(&self, Allocator a)
{
    self.alloc = a;
    self.dense.init(a);
}

fn void SparseSet.free(&self)
{
    foreach (p : self.pages) if (p) alloc::free(self.alloc, p);
    self.dense.free();
}

// Позиция id в dense или EMPTY. Не выделяет память.
fn uint SparseSet.sparse_get(&self, uint id)
{
    uint* page = self.pages[id / PAGE_SIZE];
    if (!page) return EMPTY;
    return page[id % PAGE_SIZE];
}

// Указатель на ячейку sparse для id; страница выделяется при необходимости.
fn uint* SparseSet.sparse_ref(&self, uint id)
{
    uint pi = id / PAGE_SIZE;
    if (!self.pages[pi])
    {
        uint* page = alloc::new_array(self.alloc, uint, PAGE_SIZE);
        for (uint i = 0; i < PAGE_SIZE; i++) page[i] = EMPTY;
        self.pages[pi] = page;
        self.pages_allocated++;
    }
    return &self.pages[pi][id % PAGE_SIZE];
}

fn bool SparseSet.contains(&self, uint id) => self.sparse_get(id) != EMPTY;
fn sz SparseSet.len(&self) => self.dense.len();

fn bool SparseSet.add(&self, uint id)
{
    if (self.contains(id)) return false;
    *self.sparse_ref(id) = (uint)self.dense.len();
    self.dense.push(id);
    return true;
}

fn bool SparseSet.remove(&self, uint id)
{
    uint pos = self.sparse_get(id);
    if (pos == EMPTY) return false;
    uint last_id = self.dense[self.dense.len() - 1];
    self.dense[pos] = last_id;
    *self.sparse_ref(last_id) = pos;
    *self.sparse_ref(id) = EMPTY;
    (void)self.dense.pop();
    return true;
}

int probes;   // сколько раз intersect вызвал contains

// Записывает в out все id, входящие во ВСЕ множества; возвращает их число.
// Порядок результата — порядок dense самого маленького множества.
fn int intersect(SparseSet*[] sets, uint[] out)
{
    SparseSet* smallest = sets[0];
    foreach (s : sets) if (s.len() < smallest.len()) smallest = s;
    int n = 0;
    foreach (id : smallest.dense.array_view())
    {
        bool all = true;
        foreach (s : sets)
        {
            if (s == smallest) continue;
            probes++;
            if (!s.contains(id)) { all = false; break; }
        }
        if (all) out[n++] = id;
    }
    return n;
}

fn void main()
{
    SparseSet pos;
    SparseSet vel;
    SparseSet ai;
    pos.init(mem);
    vel.init(mem);
    ai.init(mem);
    defer { pos.free(); vel.free(); ai.free(); }

    assert(!pos.contains(60000) && pos.pages_allocated == 0, "contains() must not allocate pages");
    assert(pos.add(5) && pos.add(1234) && pos.add(60000));
    assert(!pos.add(1234), "duplicate add");
    assert(pos.contains(1234) && !pos.contains(1235) && !pos.contains(4));
    assert(pos.pages_allocated == 3, "ids 5, 1234, 60000 live in three different pages");
    assert(pos.remove(5));
    assert(!pos.contains(5) && pos.contains(60000) && pos.contains(1234));
    assert(pos.dense[0] == 60000, "swap-remove: the last id moved into the hole");
    assert(!pos.remove(5) && !pos.remove(777));
    io::printfn("pos: len=%d pages=%d", pos.len(), pos.pages_allocated);

    // Мир: 2000 сущностей с позицией, у каждой 3-й скорость, у каждой 50-й ИИ.
    for (uint e = 0; e < 2000; e++)
    {
        pos.add(e);
        if (e % 3 == 0) vel.add(e);
        if (e % 50 == 0) ai.add(e);
    }
    // Часть сущностей теряет скорость.
    for (uint e = 0; e < 2000; e += 9) vel.remove(e);
    io::printfn("sizes: pos=%d vel=%d ai=%d", pos.len(), vel.len(), ai.len());

    uint[2000] out;
    probes = 0;
    SparseSet*[] q = { &pos, &vel, &ai };
    int n = intersect(q, &out);
    io::printf("pos & vel & ai (%d, probes=%d):", n, probes);
    for (int i = 0; i < n; i++) io::printf(" %d", out[i]);
    io::printn();
    for (int i = 0; i < n; i++) assert(out[i] % 150 == 0 && out[i] % 9 != 0);
    assert(n == 9);
    assert(probes <= 2 * (int)ai.len(), "iterate the SMALLEST set: probes must be <= 2*|ai|");

    probes = 0;
    SparseSet*[] q2 = { &pos, &vel };
    int m = intersect(q2, &out);
    io::printfn("pos & vel: %d (probes=%d)", m, probes);
    assert(m == (int)vel.len() && probes == (int)vel.len());
    io::printn("sparse set OK");
}
