// =====================================================================
//  e0803 · Плоская иерархия: «родитель раньше ребёнка»
// =====================================================================
//
//  Сначала прочитайте engine/docs/08_scene.md (раздел 5).
//
//  Рекурсивный обход дерева узлов-объектов — это прыжки по памяти
//  и промахи кэша. Современные движки (Bitsquid/Stingray, Our
//  Machinery, Unity DOTS, иерархия скелета в любом движке) хранят
//  иерархию ПЛОСКО — несколькими параллельными массивами (SoA):
//
//      index:   0      1      2      3      4
//      parent: -1      0      0      1      3
//      local:  ...    ...    ...    ...    ...
//      world:  ...    ...    ...    ...    ...
//
//  и поддерживают ОДИН инвариант:
//
//      parent[i] < i   для каждого не-корня.
//
//  Тогда мировые трансформации считаются одним линейным проходом без
//  рекурсии и без стека — к моменту обработки узла i world его
//  родителя уже посчитан:
//
//      for i in 0..n: world[i] = parent[i] < 0 ? local[i]
//                                              : world[parent[i]] * local[i]
//
//  Цена — поддерживать порядок. Когда узлы приходят в произвольном
//  порядке (загрузка уровня, смена родителя), массив переупорядочивают.
//  Простой способ — устойчивая сортировка по глубине узла (корни
//  глубины 0, их дети — 1, ...). Самое коварное при любой перестановке
//  — НЕ ЗАБЫТЬ ПЕРЕНУМЕРОВАТЬ ссылки parent: старые индексы больше
//  ничего не значат. Для этого строят таблицу remap[old] = new.
//
//  Здесь трансформации — целочисленные сдвиги (IVec), чтобы внимание
//  было на порядке, а не на матрицах: world = world(parent) + local.
//
//  ЗАДАЧА: реализуйте
//    * Hierarchy.update_world   — один линейный проход;
//    * Hierarchy.sort_by_depth  — устойчивая перестановка узлов по
//      глубине (при равной глубине сохраняется прежний относительный
//      порядок) с перенумерацией parent.
//  reparent() уже написан и пользуется вашей сортировкой.
//
import std::io;

const int MAX = 16;
const int NO_PARENT = -1;

struct IVec { int x, y; }

fn IVec IVec.add(self, IVec o) @operator(+) => { self.x + o.x, self.y + o.y };

// Структура массивов (SoA): i-й узел — это i-е элементы всех массивов.
struct Hierarchy
{
    int count;
    String[MAX] name;
    int[MAX] parent;
    IVec[MAX] local;
    IVec[MAX] world;
}

fn int Hierarchy.add(&self, String name, int parent, IVec local)
{
    int i = self.count++;
    self.name[i] = name;
    self.parent[i] = parent;
    self.local[i] = local;
    return i;
}

fn int Hierarchy.find(&self, String name)
{
    for (int i = 0; i < self.count; i++) if (self.name[i] == name) return i;
    return NO_PARENT;
}

fn bool Hierarchy.is_parent_first(&self)
{
    for (int i = 0; i < self.count; i++) if (self.parent[i] >= i) return false;
    return true;
}

fn int Hierarchy.depth(&self, int i)
{
    int d = 0;
    for (int p = self.parent[i]; p != NO_PARENT; p = self.parent[p]) d++;
    return d;
}

<*
 @require self.is_parent_first() : "update_world needs parent-before-child order"
*>
fn void Hierarchy.update_world(&self)
{
    // TODO: один проход i = 0..count-1:
    //       world[i] = local[i] для корня, иначе world[parent[i]] + local[i].
    for (int i = 0; i < self.count; i++) self.world[i] = self.local[i];
}

fn void Hierarchy.sort_by_depth(&self)
{
    // TODO:
    //   1. Постройте order[new] = old: сначала все узлы глубины 0 (в
    //      прежнем порядке), потом глубины 1, ... (self.depth(i) уже есть).
    //   2. Постройте обратную таблицу remap[old] = new.
    //   3. Скопируйте *self во временную переменную (`Hierarchy old = *self;`
    //      — структура с массивами копируется по значению) и переложите
    //      name/local/world/parent на новые места. parent нужно
    //      перенумеровать через remap (NO_PARENT остаётся NO_PARENT).
}

// Смена родителя может нарушить инвариант — тогда пересортировываем.
fn void Hierarchy.reparent(&self, int child, int new_parent)
{
    self.parent[child] = new_parent;
    if (new_parent > child) self.sort_by_depth();
}

// ---------------------------------------------------------------------
// Ниже — тесты. Менять не нужно.
// ---------------------------------------------------------------------

fn void Hierarchy.print(&self)
{
    for (int i = 0; i < self.count; i++)
    {
        String pname = self.parent[i] == NO_PARENT ? "-" : self.name[self.parent[i]];
        io::printfn("  %2d %-8s parent=%-8s world=(%d, %d)", i, self.name[i], pname,
                    self.world[i].x, self.world[i].y);
    }
}

fn void expect_world(Hierarchy* h, String name, int x, int y)
{
    int i = h.find(name);
    assert(i != NO_PARENT, "node %s is lost", name);
    assert(h.world[i].x == x && h.world[i].y == y, "%s: expected (%d, %d), got (%d, %d)",
           name, x, y, h.world[i].x, h.world[i].y);
}

fn void main()
{
    // Узлы пришли «из файла уровня» вперемешку: дети раньше родителей.
    Hierarchy h;
    h.add("wheel",  3, { 1, -1 });   // 0, родитель — car (3)
    h.add("hat",    2, { 0, 2 });    // 1, родитель — driver (2)
    h.add("driver", 3, { 0, 1 });    // 2, родитель — car (3)
    h.add("car",    NO_PARENT, { 10, 0 }); // 3
    h.add("lamp",   NO_PARENT, { 50, 5 }); // 4
    h.add("bulb",   4, { 0, 3 });    // 5
    assert(!h.is_parent_first());

    h.sort_by_depth();
    assert(h.is_parent_first(), "after sorting every parent must precede its children");
    assert(h.name[0] == "car" && h.name[1] == "lamp", "depth 0 nodes keep their relative order");
    assert(h.name[2] == "wheel" && h.name[3] == "driver" && h.name[4] == "bulb" && h.name[5] == "hat",
           "sort must be stable by depth");
    h.update_world();
    expect_world(&h, "hat", 10, 3);
    expect_world(&h, "wheel", 11, -1);
    expect_world(&h, "bulb", 50, 8);
    io::printn("after load + sort:");
    h.print();

    // Шляпу снимают с водителя и вешают на лампочку (bulb стоит раньше шляпы —
    // пересортировка не нужна). Затем водитель цепляется за шляпу (!) —
    // теперь родитель стоит ПОСЛЕ ребёнка, и нужна пересортировка.
    h.reparent(h.find("hat"), h.find("bulb"));
    h.local[h.find("hat")] = { 0, 1 };
    h.reparent(h.find("driver"), h.find("hat"));
    assert(h.is_parent_first(), "reparent must restore the invariant");
    h.update_world();
    expect_world(&h, "hat", 50, 9);
    expect_world(&h, "driver", 50, 10);
    expect_world(&h, "car", 10, 0);
    io::printn("after reparenting:");
    h.print();

    // Двигаем корень: один линейный проход обновляет всех.
    h.local[h.find("lamp")] = { 0, 0 };
    h.update_world();
    expect_world(&h, "driver", 0, 5);
    io::printfn("driver after moving lamp: (%d, %d)", h.world[h.find("driver")].x, h.world[h.find("driver")].y);
    io::printn("flat hierarchy ok");
}
