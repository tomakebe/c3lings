// =====================================================================
//  114 · Дерево в арене с индексами вместо указателей
// =====================================================================
//
//  Деревья повсюду: граф сцены, иерархия костей скелета, DOM UI,
//  AST компилятора, BVH для лучей. Учебная реализация — узел на куче и
//  указатели на детей:
//
//      struct Node { Node* parent; Node*[] children; ... }
//
//  Для движка это плохо: тысячи мелких аллокаций, узлы раскиданы по
//  памяти (обход = промах кеша на каждом шаге), освобождение — рекурсивный
//  обход, сериализация требует превращения указателей в номера и обратно,
//  а копирование дерева — глубокое клонирование.
//
//  АРЕНА + ИНДЕКСЫ
//  ---------------
//  Все узлы лежат в одном массиве (List), ссылки — номера в нём:
//
//      typedef NodeId = uint;     // 0 = «нет узла»
//      struct Node { NodeId parent, first_child, last_child, next_sibling; ... }
//
//  * Одна аллокация (амортизированно), узлы лежат плотно.
//  * Индексы переживают realloc массива — указатели бы протухли!
//    Поэтому НИКОГДА не держите `Node*` через вызов, который может
//    добавить узел: `Node* p = tree.get(x); tree.add_child(...); p.value = 1;`
//    — классический use-after-realloc.
//  * Сериализация = записать массив как есть. Копия дерева = memcpy.
//  * Удалить всё дерево = освободить один массив.
//  * 4-байтный индекс вместо 8-байтного указателя: узлы меньше.
//  Так устроены rustc (arena + Idx), Roslyn/clang в части структур,
//  иерархии трансформов (Unity, Bevy), ozz-animation (кости — плоский
//  массив с индексом родителя), Dear ImGui (ImPool), indextree/slotmap.
//
//  ПРЕДСТАВЛЕНИЕ ДЕТЕЙ «first child / next sibling»
//  ------------------------------------------------
//  Вместо массива детей у каждого узла (ещё аллокации!) храним лишь
//  первого ребёнка и следующего брата — любое дерево становится
//  бинарным по структуре. Плюс last_child, чтобы добавлять в конец за
//  O(1). Обход детей:
//      for (NodeId c = n.first_child; c != NONE; c = node(c).next_sibling)
//
//  ОБХОД БЕЗ РЕКУРСИИ
//  ------------------
//  Рекурсия на дереве глубиной 100 000 (длинный список, вырожденное AST)
//  переполнит стек. Явный стек в List — надёжнее, и его память
//  переиспользуется между вызовами. Для печати мы оставим рекурсию —
//  так нагляднее, — а сумму поддерева посчитаем явным стеком.
//
//  ПЕРЕНОС ПОДДЕРЕВА (reparent) — две ловушки:
//  * отцепить узел от старого родителя: в односвязном списке братьев
//    нужно найти предыдущего брата, а если узел был last_child —
//    поправить и его;
//  * нельзя сделать узел ребёнком собственного потомка — получится цикл,
//    и любой обход зависнет. Проверка: поднимаемся от нового родителя
//    по parent до корня; встретили переносимый узел — ошибка.
//
//  ЗАДАЧА: реализуйте add_child, detach, attach (с проверкой цикла),
//  subtree_sum (явный стек) и write_sexpr (рекурсия).
//
import std::io;
import std::collections::list;

typedef NodeId = uint;
const NodeId NONE = (NodeId)0;

excuse CYCLE;

struct Node
{
    String name;
    int value;
    NodeId parent;
    NodeId first_child;
    NodeId last_child;
    NodeId next_sibling;
}

struct Tree
{
    List{Node} nodes;      // nodes[0] — фиктивный узел для NONE
    List{NodeId} stack;    // переиспользуемый стек обхода
}

fn void Tree.init(&self)
{
    self.nodes.init(mem);
    self.stack.init(mem);
    self.nodes.push({ .name = "<none>" });
}

fn void Tree.free(&self)
{
    self.nodes.free();
    self.stack.free();
}

// Указатель валиден только до следующего добавления узла!
fn Node* Tree.node(&self, NodeId id) @inline => self.nodes.get_ref((uint)id);

fn NodeId Tree.new_root(&self, String name, int value)
{
    NodeId id = (NodeId)(uint)self.nodes.len();
    self.nodes.push({ .name = name, .value = value });
    return id;
}

// Добавить id последним ребёнком parent (id сейчас не должен иметь родителя).
fn void Tree.link_last(&self, NodeId parent, NodeId id)
{
    // TODO: id.parent = parent; если у parent нет детей — first_child = id,
    //       иначе last_child.next_sibling = id; затем last_child = id.
}

fn NodeId Tree.add_child(&self, NodeId parent, String name, int value)
{
    NodeId id = self.new_root(name, value);
    self.link_last(parent, id);
    return id;
}

// Отцепить узел от родителя (вместе с поддеревом).
fn void Tree.detach(&self, NodeId id)
{
    // TODO:
    //  * если parent == NONE — ничего не делать;
    //  * найти предыдущего брата prev (NONE, если id — first_child);
    //  * перешить: first_child или prev.next_sibling = id.next_sibling;
    //  * если id был last_child — last_child = prev;
    //  * обнулить у id parent и next_sibling.
}

// Перенести поддерево id под new_parent (в конец списка детей).
fn void? Tree.attach(&self, NodeId id, NodeId new_parent)
{
    // TODO: проверка цикла (подняться от new_parent к корню), затем detach + link_last.
}

fn long Tree.subtree_sum(&self, NodeId root)
{
    // TODO: без рекурсии: self.stack.clear(); push(root);
    //       пока стек не пуст — pop, прибавить value, положить всех детей.
    return 0;
}

// Формат: лист — "name"; узел с детьми — "(name child1 child2 ...)".
fn void Tree.write_sexpr(&self, NodeId id, DString* out)
{
    // TODO (рекурсивно)
}

fn String Tree.tsexpr(&self, NodeId id)
{
    DString s = dstring::temp();
    self.write_sexpr(id, &s);
    return s.str_view();
}

// ---------------------------------------------------------------- проверка

fn void main()
{
    Tree t;
    t.init();
    defer t.free();

    NodeId world = t.new_root("world", 0);
    NodeId player = t.add_child(world, "player", 10);
    NodeId gun = t.add_child(player, "gun", 5);
    NodeId hat = t.add_child(player, "hat", 1);
    NodeId car = t.add_child(world, "car", 20);
    NodeId wheel = t.add_child(car, "wheel", 2);
    t.add_child(car, "wheel", 2);
    NodeId light = t.add_child(world, "light", 0);

    @pool()
    {
        String s = t.tsexpr(world);
        io::printfn("scene: %s", s);
        assert(s == "(world (player gun hat) (car wheel wheel) light)", "bad tree: %s", s);
    };
    assert(t.subtree_sum(world) == 40 && t.subtree_sum(player) == 16);

    // игрок садится в машину, оружие берём в руку
    t.attach(player, car)!!;
    t.detach(gun);
    assert(t.node(player).last_child == hat, "last_child not fixed after detach of first child");
    t.attach(gun, world)!!;
    t.detach(light);                   // light — last_child мира
    t.attach(light, gun)!!;
    @pool()
    {
        String s = t.tsexpr(world);
        io::printfn("scene: %s", s);
        assert(s == "(world (car wheel wheel (player hat)) (gun light))", "bad tree: %s", s);
    };
    assert(t.node(world).last_child == gun);

    // циклы запрещены
    assert(@catch(t.attach(car, wheel)) == CYCLE, "attaching to own descendant must fail");
    assert(@catch(t.attach(world, world)) == CYCLE);
    assert(t.subtree_sum(car) == 35, "car subtree: %d", t.subtree_sum(car));

    // Индексы переживают рост массива (указатели бы не пережили).
    NodeId chain = hat;
    for (int i = 0; i < 100_000; i++) chain = t.add_child(chain, "link", 1);
    assert(t.node(hat).name == "hat" && t.node(wheel).name == "wheel");
    // глубина 100 000 — рекурсивная сумма могла бы переполнить стек
    long total = t.subtree_sum(world);
    assert(total == 40 + 100_000);
    io::printfn("nodes=%d total=%d", t.nodes.len() - 1, total);
}
