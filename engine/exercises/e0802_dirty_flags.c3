// =====================================================================
//  e0802 · Dirty flags: ленивый пересчёт мировых трансформаций
// =====================================================================
//
//  Сначала прочитайте engine/docs/08_scene.md (раздел 4).
//
//  Пересчитывать world всех узлов каждый кадр дорого, если двигается
//  1% объектов. Пересчитывать world при КАЖДОМ set_local — ещё хуже:
//  геймплей может подвинуть руку персонажа пять раз за кадр, и каждый
//  раз мы пересчитаем всё поддерево.
//
//  Паттерн Dirty Flag (Nystrom, «Game Programming Patterns»):
//
//    * set_local(i)  — меняет локальную матрицу и помечает узел и ВСЁ
//                      его поддерево «грязным». Ничего не считает.
//    * get_world(i)  — если узел чистый, отдаёт кэш. Если грязный —
//                      сначала получает world родителя (рекурсивно,
//                      тем же get_world), умножает, кэширует, снимает флаг.
//
//  Главный инвариант, на котором держится всё остальное:
//
//      если узел грязный, то грязны и все его потомки.
//
//  Благодаря ему mark_dirty может остановиться, встретив уже грязный
//  узел: ниже него всё и так помечено. Без этого раннего выхода
//  1000 вызовов set_local(root) обходили бы всё дерево 1000 раз.
//
//    set_local(root) x1000, дерево из N узлов
//      без раннего выхода:  1000 * N посещений
//      с ранним выходом:    N + 999 посещений
//
//  Дети хранятся в виде first_child / next_sibling (интрузивный
//  список) — без отдельных аллокаций на каждый узел.
//
//  ЗАДАЧА: реализуйте Scene.mark_dirty и Scene.get_world.
//    * mark_dirty должен увеличивать self.mark_visits на каждый
//      вызов (включая ранний выход) — по нему тест проверит, что
//      ранний выход работает;
//    * get_world должен увеличивать self.recomputes на каждый
//      реальный пересчёт матрицы.
//
import std::io;
import std::math;
import std::collections::list;

const int NONE = -1;

struct Vec2 { float x, y; }
struct Affine2 { float a, b, c, d, tx, ty; }

fn Affine2 identity() => { 1, 0, 0, 1, 0, 0 };
fn Affine2 translate(float x, float y) => { 1, 0, 0, 1, x, y };
fn Affine2 scale(float s) => { s, 0, 0, s, 0, 0 };

fn Affine2 Affine2.mul(self, Affine2 c)
{
    return {
        self.a * c.a + self.c * c.b,
        self.b * c.a + self.d * c.b,
        self.a * c.c + self.c * c.d,
        self.b * c.c + self.d * c.d,
        self.a * c.tx + self.c * c.ty + self.tx,
        self.b * c.tx + self.d * c.ty + self.ty,
    };
}

struct Node
{
    int parent;
    int first_child;
    int next_sibling;
    Affine2 local;
    Affine2 world;     // кэш; валиден только если !dirty
    bool dirty;
}

struct Scene
{
    List{Node} nodes;
    int mark_visits;
    int recomputes;
}

fn void Scene.free(&self) => self.nodes.free();

fn int Scene.add(&self, int parent, Affine2 local)
{
    int id = (int)self.nodes.len();
    Node n = { .parent = parent, .first_child = NONE, .next_sibling = NONE, .local = local, .dirty = true };
    if (parent != NONE)
    {
        n.next_sibling = self.nodes[parent].first_child;
        self.nodes[parent].first_child = id;
    }
    self.nodes.push(n);
    return id;
}

fn void Scene.set_local(&self, int i, Affine2 local)
{
    self.nodes[i].local = local;
    self.mark_dirty(i);
}

fn void Scene.mark_dirty(&self, int i)
{
    self.mark_visits++;
    // TODO: пометьте узел i и всё его поддерево грязным.
    //       Не забудьте ранний выход (см. инвариант в шапке).
    //       Детей обходите так:
    //       for (int c = node.first_child; c != NONE; c = self.nodes[c].next_sibling)
    self.nodes[i].dirty = true;
}

fn Affine2 Scene.get_world(&self, int i)
{
    // TODO: если узел чистый — верните кэш world.
    //       Иначе: world = world(родителя) * local (у корня — просто local),
    //       сохраните в кэш, снимите флаг, увеличьте self.recomputes.
    self.recomputes++;
    return self.nodes[i].local;
}

// ---------------------------------------------------------------------
// Ниже — тесты. Менять не нужно.
// ---------------------------------------------------------------------

fn bool near(float a, float b) => math::abs(a - b) < 0.001f;

fn void Scene.reset_counters(&self)
{
    self.mark_visits = 0;
    self.recomputes = 0;
}

fn void main()
{
    Scene s;
    defer s.free();
    int root   = s.add(NONE, translate(100, 0));
    int arm    = s.add(root, translate(10, 0));
    int hand   = s.add(arm, translate(5, 0));
    int finger = s.add(hand, translate(1, 0));
    int thumb  = s.add(hand, translate(0, 1));
    int leg    = s.add(root, translate(0, -10));
    int foot   = s.add(leg, translate(0, -5));

    // Первое чтение пальца: пересчитываются root, arm, hand, finger.
    Affine2 w = s.get_world(finger);
    assert(near(w.tx, 116) && near(w.ty, 0), "finger world");
    assert(s.recomputes == 4, "first read must recompute the 4-node chain");
    io::printfn("first read finger:  recomputes=%d", s.recomputes);

    // Повторное чтение — из кэша.
    s.reset_counters();
    s.get_world(finger);
    s.get_world(hand);
    assert(s.recomputes == 0, "clean nodes must come from cache");
    io::printfn("cached reads:       recomputes=%d", s.recomputes);

    // Двигаем руку пять раз за "кадр" — пересчётов ноль, пока никто не читает.
    s.reset_counters();
    for (int k = 1; k <= 5; k++) s.set_local(arm, translate((float)(10 + k), 0));
    assert(s.recomputes == 0, "set_local must not recompute anything");
    io::printfn("5x set_local(arm):  mark_visits=%d recomputes=%d", s.mark_visits, s.recomputes);
    assert(s.mark_visits == 4 + 4, "repeated marking must stop at an already dirty node");

    // Читаем большой палец: root чистый, arm/hand/thumb пересчитываются.
    w = s.get_world(thumb);
    assert(near(w.tx, 120) && near(w.ty, 1), "thumb after moving arm");
    assert(s.recomputes == 3, "only the dirty part of the chain is recomputed");
    io::printfn("read thumb:         recomputes=%d", s.recomputes);

    // Масштаб корня влияет на всех; 1000 изменений корня — дёшево.
    s.reset_counters();
    for (int k = 0; k < 1000; k++) s.set_local(root, translate(0, 0).mul(scale(2)));
    io::printfn("1000x set_local(root): mark_visits=%d", s.mark_visits);
    assert(s.mark_visits < 1100, "early-out in mark_dirty is missing");
    w = s.get_world(foot);
    assert(near(w.tx, 0) && near(w.ty, -30), "foot after scaling root");
    w = s.get_world(finger);
    assert(near(w.tx, 42) && near(w.ty, 0), "finger after scaling root");
    io::printfn("read foot+finger:   recomputes=%d", s.recomputes);
    // root, leg, foot, arm, hand, finger — thumb никто не читал, он остался грязным.
    assert(s.recomputes == 6, "each node on the read paths recomputed exactly once");
    io::printn("dirty flags ok");
}
