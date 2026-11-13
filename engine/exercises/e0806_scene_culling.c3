// =====================================================================
//  e0806 · Сцена целиком: иерархия + границы поддеревьев + отсечение
// =====================================================================
//
//  Сначала прочитайте engine/docs/08_scene.md (разделы 5, 6 и 9).
//
//  Финал главы собирает всё вместе. Сцена — плоские массивы в порядке
//  обхода в глубину (DFS preorder). Это частный случай «родитель
//  раньше ребёнка» с бонусом: всё поддерево узла i лежит ПОДРЯД, в
//  диапазоне [i, subtree_end[i]).
//
//      i:            0     1      2     3     4      5     6
//      node:       city  distA  bldg  lamp  bldg  distB  bldg
//      parent:      -1     0      1     2     1      0     5
//      subtree_end:  7     5      4     4     5      7     7
//
//  Каждый кадр — три линейных прохода:
//
//   1) ВПЕРЁД (i = 0..n-1): мировая позиция и мировой AABB узла.
//          world_pos[i] = world_pos[parent] + local_pos[i]
//          world_box[i] = local_box[i] сдвинутый на world_pos[i]
//      У «групп» (район, корень) своей геометрии нет — пустой AABB.
//
//   2) НАЗАД (i = n-1..0): границы поддерева.
//          sub_box[i] = world_box[i] ∪ (sub_box всех детей)
//      Идём с конца: к моменту, когда мы на узле i, все его дети уже
//      «влили» в него свои sub_box. Узел вливает свой sub_box в
//      родителя — и всё, никакой рекурсии.
//
//   3) ОТСЕЧЕНИЕ (culling) по прямоугольнику камеры: идём i = 0..n-1;
//      если sub_box[i] не пересекается с видом — всё поддерево
//      невидимо, и мы ПЕРЕПРЫГИВАЕМ его: i = subtree_end[i]. Это и есть
//      иерархическое отсечение (так делали в scene graph'ах эпохи
//      OpenSceneGraph/Ogre, а BVH делает то же для произвольных
//      объектов). Иначе проверяем собственный world_box и идём в i+1.
//
//  Пустой AABB кодируется min > max (EMPTY ниже): объединение с ним
//  ничего не меняет, а пересечение всегда ложно — никаких особых
//  случаев в коде.
//
//  ЗАДАЧА: реализуйте Scene.update_world, Scene.update_bounds и
//  Scene.cull. Тест сравнит результат отсечения с перебором всех узлов
//  и проверит, что иерархия сэкономила проверки.
//
import std::io;

const int MAX = 128;
const int NO_PARENT = -1;

struct IVec { int x, y; }

struct Box { int min_x, min_y, max_x, max_y; }

const Box EMPTY = { int::max, int::max, int::min, int::min };

fn bool Box.is_empty(self) => self.min_x > self.max_x;

fn Box Box.merge(self, Box o)
{
    return {
        self.min_x < o.min_x ? self.min_x : o.min_x,
        self.min_y < o.min_y ? self.min_y : o.min_y,
        self.max_x > o.max_x ? self.max_x : o.max_x,
        self.max_y > o.max_y ? self.max_y : o.max_y,
    };
}

fn bool Box.overlaps(self, Box o)
{
    return self.min_x <= o.max_x && o.min_x <= self.max_x
        && self.min_y <= o.max_y && o.min_y <= self.max_y;
}

fn Box Box.offset(self, IVec v)
{
    if (self.is_empty()) return self;
    return { self.min_x + v.x, self.min_y + v.y, self.max_x + v.x, self.max_y + v.y };
}

struct Scene
{
    int count;
    String[MAX] name;
    int[MAX] parent;
    int[MAX] subtree_end;
    IVec[MAX] local_pos;
    Box[MAX] local_box;
    IVec[MAX] world_pos;
    Box[MAX] world_box;
    Box[MAX] sub_box;
    int tests;          // сколько проверок AABB сделал cull
}

// Узлы добавляются в порядке DFS: ребёнка можно добавить только к
// узлу, чьё поддерево сейчас «открыто» (последний путь от корня).
// add поддерживает subtree_end у всех предков.
fn int Scene.add(&self, String name, int parent, IVec pos, Box box)
{
    int i = self.count++;
    self.name[i] = name;
    self.parent[i] = parent;
    self.local_pos[i] = pos;
    self.local_box[i] = box;
    self.subtree_end[i] = i + 1;
    for (int p = parent; p != NO_PARENT; p = self.parent[p])
    {
        assert(self.subtree_end[p] == i, "nodes must be added in DFS order");
        self.subtree_end[p] = i + 1;
    }
    return i;
}

fn void Scene.update_world(&self)
{
    // TODO: проход 1 (вперёд): world_pos и world_box каждого узла.
    //       У корня база — (0, 0). Сдвиг коробки — local_box[i].offset(...).
}

fn void Scene.update_bounds(&self)
{
    // TODO: проход 2 (назад): sub_box[i] = world_box[i], затем с конца
    //       к началу вливайте sub_box[i] в sub_box[parent[i]] (Box.merge).
    //       Подумайте, почему идти нужно именно с конца.
}

// Записывает индексы видимых узлов (с непустым world_box) в out,
// возвращает их число.
fn int Scene.cull(&self, Box view, int[] out)
{
    // TODO: проход 3: while (i < self.count). На каждом узле:
    //   * self.tests++ и проверка sub_box[i] против view; если мимо —
    //     i = subtree_end[i] (пропуск всего поддерева);
    //   * иначе, если world_box[i] непуст: self.tests++ и, при
    //     пересечении, out[n++] = i; затем i++.
    return 0;
}

// ---------------------------------------------------------------------
// Ниже — тесты. Менять не нужно.
// ---------------------------------------------------------------------

fn int Scene.find(&self, String name)
{
    for (int i = 0; i < self.count; i++) if (self.name[i] == name) return i;
    return NO_PARENT;
}

fn void build_city(Scene* s)
{
    int root = s.add("city", NO_PARENT, { 0, 0 }, EMPTY);
    String[4] districts = { "north", "east", "south", "west" };
    IVec[4] origins = { { 0, 0 }, { 2000, 0 }, { 0, 2000 }, { 2000, 2000 } };
    for (int d = 0; d < 4; d++)
    {
        int dist = s.add(districts[d], root, origins[d], EMPTY);
        for (int b = 0; b < 5; b++)
        {
            int bldg = s.add("building", dist, { b * 300, (b % 2) * 300 }, { 0, 0, 200, 150 });
            s.add("lamp", bldg, { -20, 0 }, { -5, -5, 5, 5 });
            s.add("tree", bldg, { 230, 170 }, { -30, -30, 30, 30 });
        }
    }
}

fn uint run_view(Scene* s, String label, Box view)
{
    int[MAX] vis;
    s.tests = 0;
    int n = s.cull(view, &vis);
    // Перебор: каждая непустая коробка против вида.
    int m = 0;
    int brute_tests = 0;
    uint sum = 0;
    for (int i = 0; i < s.count; i++)
    {
        if (s.world_box[i].is_empty()) continue;
        brute_tests++;
        if (!s.world_box[i].overlaps(view)) continue;
        assert(m < n && vis[m] == i, "%s: cull result differs from brute force at node %d", label, i);
        m++;
        sum = sum * 31 + (uint)i;
    }
    assert(n == m, "%s: cull found %d, brute force %d", label, n, m);
    if (label != "all") assert(s.tests < brute_tests, "%s: hierarchy did not skip anything", label);
    io::printfn("%-9s visible=%2d tests=%3d (brute force: %d) checksum=%d", label, n, s.tests, brute_tests, sum);
    return sum;
}

fn void main()
{
    Scene s;
    build_city(&s);
    assert(s.subtree_end[0] == s.count);
    s.update_world();
    s.update_bounds();

    int lamp = 3;   // первая лампа первого здания района north
    assert(s.name[lamp] == "lamp" && s.world_pos[lamp].x == -20, "lamp world position");
    Box nb = s.sub_box[s.find("north")];
    io::printfn("north bounds: (%d, %d) - (%d, %d)", nb.min_x, nb.min_y, nb.max_x, nb.max_y);
    assert(nb.min_x == -25 && nb.min_y == -5 && nb.max_x == 1460 && nb.max_y == 500, "north subtree bounds");
    Box cb = s.sub_box[0];
    assert(cb.max_x == 3460 && cb.max_y == 2500, "city bounds must contain every district");

    run_view(&s, "north-w", { 0, 0, 400, 400 });
    run_view(&s, "gap", { 1600, 900, 1900, 1900 });
    run_view(&s, "east", { 2500, 100, 2700, 200 });
    run_view(&s, "all", { -10000, -10000, 10000, 10000 });

    // Кадр 2: район west уезжает на 5000 вправо — перерасчёт двумя проходами.
    s.local_pos[s.find("west")] = { 7000, 2000 };
    s.update_world();
    s.update_bounds();
    Box wb = s.sub_box[s.find("west")];
    assert(wb.min_x == 6975, "moved district bounds");
    run_view(&s, "far-east", { 6900, 1900, 7600, 2400 });
    io::printn("scene culling ok");
}
