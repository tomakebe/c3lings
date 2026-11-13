// =====================================================================
//  E0303 · Generic slot map с плотным массивом
// =====================================================================
//
//  Сначала прочитайте engine/docs/03_containers.md (раздел 4).
//
//  Slot map = стабильные handles + плотное хранение + O(1) всё:
//
//      handle {index, gen}
//            │
//            v
//      slots:          [ gen | dense / next_free ] ...   (косвенность)
//            │
//            v
//      dense:          [ v ][ v ][ v ][ v ]               (данные подряд)
//      dense_to_slot:  [ 3 ][ 0 ][ 5 ][ 1 ]               (обратные ссылки)
//
//  Слот либо занят (тогда `dense` — позиция значения в плотном массиве),
//  либо свободен (тогда `next_free` — следующий свободный слот; список
//  свободных слотов живёт прямо в слотах, NO_SLOT — конец списка).
//  В нашей версии оба поля хранятся раздельно для наглядности.
//
//    insert(v): слот из головы свободного списка (или новый в конце
//               slots с gen = 1); dense.push(v); связать слот и позицию.
//    remove(h): проверить h; swap-remove в dense и dense_to_slot,
//               не забыв обновить слот ПЕРЕЕХАВШЕГО значения; gen++;
//               слот — в голову свободного списка.
//    get(h):    проверить h и вернуть указатель на значение в dense
//               (или null). Указатель живёт только до следующего
//               insert/remove — храните handles, а не указатели!
//
//  Тест в main сверяет slot map с «эталонной моделью» на тысячах
//  случайных операций (ГПСЧ с фиксированным seed).
//
//  ЗАДАЧА: реализуйте SlotMap.insert, SlotMap.remove, SlotMap.get.
//
import std::io, std::collections::list;

struct SmHandle
{
    uint index;
    uint gen;
}

const uint NO_SLOT = uint::max;

struct Slot
{
    uint gen;
    uint dense;        // если занят
    uint next_free;    // если свободен
    bool used;
}

struct SlotMap <Type>
{
    List{Type} dense;
    List{uint} dense_to_slot;
    List{Slot} slots;
    uint free_head;
}

fn void SlotMap.init(&self, Allocator a)
{
    self.dense.init(a);
    self.dense_to_slot.init(a);
    self.slots.init(a);
    self.free_head = NO_SLOT;
}

fn void SlotMap.free(&self)
{
    self.dense.free();
    self.dense_to_slot.free();
    self.slots.free();
}

fn sz SlotMap.len(&self) => self.dense.len();

// Плотный обход: значения подряд, без дыр.
fn Type[] SlotMap.values(&self) => self.dense.array_view();

fn SmHandle SlotMap.insert(&self, Type value)
{
    // TODO: слот из свободного списка или новый (gen = 1);
    //       значение — в конец dense, номер слота — в конец dense_to_slot.
    self.dense.push(value);
    return { 0, 0 };
}

fn bool SlotMap.contains(&self, SmHandle h)
{
    if (h.index >= self.slots.len()) return false;
    Slot s = self.slots[h.index];
    return s.used && s.gen == h.gen;
}

fn Type* SlotMap.get(&self, SmHandle h)
{
    // TODO: проверить handle (contains) и вернуть указатель в dense
    return null;
}

fn bool SlotMap.remove(&self, SmHandle h)
{
    // TODO: swap-remove + обновить слот переехавшего значения;
    //       gen++, слот — в голову свободного списка.
    return false;
}

// ---------------------------------------------------------------------

struct Enemy
{
    int hp;
    float[<2>] pos;
}

fn uint rnd(uint* s)
{
    *s ^= *s << 13; *s ^= *s >> 17; *s ^= *s << 5;
    return *s;
}

fn void main()
{
    SlotMap{Enemy} enemies;
    enemies.init(mem);
    defer enemies.free();

    SmHandle a = enemies.insert({ 100, { 0, 0 } });
    SmHandle b = enemies.insert({ 50, { 1, 0 } });
    SmHandle c = enemies.insert({ 75, { 2, 0 } });
    assert(enemies.get(b) != null && enemies.get(b).hp == 50, "get() must find a live handle");
    assert(enemies.remove(a));
    assert(enemies.get(a) == null && !enemies.remove(a), "removed handle must be dead");
    assert(enemies.get(c).hp == 75, "the moved element must still be reachable by its handle");
    assert(enemies.values()[0].hp == 75 && enemies.len() == 2, "dense array has no holes");
    SmHandle d = enemies.insert({ 10, { 3, 0 } });
    assert(d.index == a.index && d.gen == a.gen + 1, "freed slot is reused with a new generation");
    assert(enemies.get(a) == null, "the old handle stays dead after slot reuse");
    int total = 0;
    foreach (e : enemies.values()) total += e.hp;
    io::printfn("enemies: len=%d total_hp=%d", enemies.len(), total);
    assert(total == 135);

    // Стресс-тест против эталонной модели.
    SlotMap{int} sm;
    sm.init(mem);
    defer sm.free();
    SmHandle[256] handles;
    int[256] expected;
    bool[256] alive;
    int n_handles = 0;
    uint seed = 2024;
    int inserts = 0;
    int removes = 0;
    int stale_checks = 0;
    for (int step = 0; step < 20000; step++)
    {
        uint r = rnd(&seed);
        if (r % 3 != 0 && n_handles < 256)
        {
            int v = (int)(r >> 8 & 0xFFFF);
            handles[n_handles] = sm.insert(v);
            expected[n_handles] = v;
            alive[n_handles] = true;
            n_handles++;
            inserts++;
        }
        else if (n_handles > 0)
        {
            int k = (int)(r >> 4) % n_handles;
            bool ok = sm.remove(handles[k]);
            assert(ok == alive[k], "remove() result disagrees with the model");
            if (ok) { removes++; } else { stale_checks++; }
            alive[k] = false;
            // Освобождаем запись модели (сам handle «забываем»).
            if (n_handles == 256 || r & 1)
            {
                handles[k] = handles[n_handles - 1];
                expected[k] = expected[n_handles - 1];
                alive[k] = alive[n_handles - 1];
                n_handles--;
            }
        }
        if (step % 997 == 0)
        {
            int live = 0;
            for (int k = 0; k < n_handles; k++)
            {
                int* p = sm.get(handles[k]);
                assert((p != null) == alive[k], "liveness mismatch");
                if (p) { assert(*p == expected[k], "value mismatch"); live++; }
            }
            assert(live <= sm.len());
        }
    }
    long sum = 0;
    foreach (v : sm.values()) sum += v;
    io::printfn("stress: inserts=%d removes=%d stale=%d len=%d slots=%d sum=%d",
                inserts, removes, stale_checks, sm.len(), sm.slots.len(), sum);
    io::printn("slot map OK");
}
