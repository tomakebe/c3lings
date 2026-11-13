// =====================================================================
//  109 · Интрузивные списки и макросы
// =====================================================================
//
//  Обычный («неинтрузивный») связный список владеет своими узлами:
//
//      struct Node { Entity* value; Node* next; }    // List{Entity*}
//
//  Каждый узел — отдельная аллокация, лишний переход по указателю, а
//  чтобы удалить сущность из списка, сначала надо НАЙТИ её узел — O(n).
//
//  ИНТРУЗИВНЫЙ список переворачивает отношение: звено списка живёт
//  ВНУТРИ объекта.
//
//      struct Entity { int id; ListNode alive; ListNode dirty; ... }
//
//  Плюсы, ради которых так делает ядро Linux (`struct list_head`),
//  FreeBSD (queue.h), Doom 3, Unreal (TIntrusiveList), аллокаторы,
//  планировщики задач, LRU-кеши в БД:
//  * Ноль аллокаций при вставке/удалении — объект уже содержит звено.
//  * Удаление за O(1) по указателю на объект: никаких поисков.
//  * Объект может одновременно состоять в нескольких списках (по
//    звену на список): «все живые», «грязные», «ждут рендера».
//  * Отлично сочетается с пулами объектов: память не двигается.
//
//  Минусы: объект должен заранее знать, в каких списках он бывает;
//  нельзя положить в список int; время жизни объекта и членства в
//  списке надо согласовывать вручную (удалили объект, не выписав из
//  списка, — висячий указатель в соседях).
//
//  КОЛЬЦЕВОЙ СПИСОК С ЧАСОВЫМ (sentinel)
//  -------------------------------------
//  Голова списка — такой же ListNode, не принадлежащий никакому
//  объекту. Пустой список: head.next == head.prev == &head. Тогда ни
//  в одной операции нет проверок на null и особых случаев «первый/
//  последний элемент» — у каждого узла всегда есть соседи:
//
//      insert_after(pos, n):   n.prev = pos; n.next = pos.next;
//                              pos.next.prev = n; pos.next = n;
//      unlink(n):              n.prev.next = n.next; n.next.prev = n.prev;
//                              n.prev = n.next = n;   // «не в списке»
//
//  Последняя строка — хорошая привычка: узел, указывающий сам на себя,
//  считается «не связанным», повторный unlink безопасен, а is_linked()
//  проверяется бесплатно.
//
//  CONTAINER_OF
//  ------------
//  Обход списка даёт нам ListNode*, а нужен Entity*. Знаем смещение
//  поля внутри структуры — вычитаем его из адреса:
//
//      (Entity*)((char*)node - offsetof(Entity, dirty))
//
//  В C это макрос container_of из ядра Linux. В C3 смещение поля даёт
//  рефлексия: `$reflect(Entity.dirty).offset`, а имя поля можно передать
//  строкой и превратить в обращение через `$eval`:
//      $reflect($Type.$eval($member)).offset
//  Макрос проверяется на этапе компиляции: опечатка в имени поля —
//  ошибка компиляции, а не мусорный указатель.
//
//  ОБХОД С УДАЛЕНИЕМ: если тело цикла может выписать текущий элемент,
//  нужно запомнить `next` ДО вызова тела (в Linux это
//  list_for_each_entry_safe). Мы так и сделаем в макросе с trailing-
//  блоком: `@list_each(&head, Entity, "dirty"; Entity* e) { ... };`
//
//  ЗАДАЧА:
//    1. Реализуйте методы ListNode: init, is_empty, is_linked,
//       insert_after, push_back, push_front, unlink.
//    2. Допишите макросы @container_of и @list_each.
//    3. Допишите LRU-кеш (Lru.touch), где порядок «давности» хранится
//       в интрузивном списке: свежие — в начале, вытесняется хвост.
//
import std::io;

struct ListNode
{
    ListNode* prev;
    ListNode* next;
}

fn void ListNode.init(&self)
{
    // TODO: пустой кольцевой список / несвязанный узел — указывает сам на себя.
    self.prev = self;
    self.next = self;
}

fn bool ListNode.is_empty(&self)
{
    // TODO
    return self.next == self;
}

// Узел состоит в каком-то списке?
fn bool ListNode.is_linked(&self) => !self.is_empty();

fn void ListNode.insert_after(&self, ListNode* n)
{
    assert(!n.is_linked(), "node is already in a list");
    // TODO: вставить n сразу после self
    n.prev = self;
    n.next = self.next;
    self.next.prev = n;
    self.next = n;
}

// self — голова (часовой) списка.
fn void ListNode.push_back(&self, ListNode* n)
{
    // TODO: «после последнего» == после self.prev
    self.prev.insert_after(n);
}

fn void ListNode.push_front(&self, ListNode* n)
{
    // TODO
    self.insert_after(n);
}

fn void ListNode.unlink(&self)
{
    // TODO: выписать узел и вернуть его в состояние «указывает на себя».
    self.prev.next = self.next;
    self.next.prev = self.prev;
    self.prev = self;
    self.next = self;
}

fn sz ListNode.count(&self)
{
    sz n = 0;
    for (ListNode* it = self.next; it != self; it = it.next) n++;
    return n;
}

// По указателю на звено `ptr` (поле `$member` структуры `$Type`) вернуть $Type*.
macro @container_of(ptr, $Type, $member)
{
    // TODO: вычесть смещение поля: $reflect($Type.$eval($member)).offset
    return ($Type*)((char*)ptr - $reflect($Type.$eval($member)).offset);
}

// Обход списка с головой `head`; тело получает $Type*. Тело может
// выписать текущий элемент — next запоминается заранее.
macro @list_each(ListNode* head, $Type, $member; @body(it))
{
    // TODO
    for (ListNode* n = head.next; n != head;)
    {
        ListNode* next = n.next;
        @body(@container_of(n, $Type, $member));
        n = next;
    }
}

// ---------------------------------------------------------------- сущности

struct Entity
{
    int id;
    int hp;
    ListNode alive;    // во всех живых
    ListNode dirty;    // в изменённых за кадр
}

fn void print_list(String title, ListNode* head, bool by_dirty)
{
    io::printf("%s:", title);
    if (by_dirty)
    {
        @list_each(head, Entity, "dirty"; Entity* e) { io::printf(" %d", e.id); };
    }
    else
    {
        @list_each(head, Entity, "alive"; Entity* e) { io::printf(" %d", e.id); };
    }
    io::printn();
}

// ---------------------------------------------------------------- LRU

const int LRU_CAP = 3;

struct CacheEntry
{
    int key;
    int value;
    bool used;
    ListNode lru;
}

struct Lru
{
    CacheEntry[LRU_CAP] entries;   // хранилище без аллокаций
    ListNode order;                // голова: свежие спереди
    int evictions;
}

fn void Lru.init(&self)
{
    *self = {};
    self.order.init();
    foreach (&e : self.entries) e.lru.init();
}

// Обращение к ключу: если есть — сделать самым свежим и вернуть true.
// Если нет — занять свободный слот, а если свободных нет — вытеснить
// самый старый (хвост списка). Новый элемент — в начало. Вернуть false.
fn bool Lru.touch(&self, int key, int value)
{
    // 1. попадание
    foreach (&e : self.entries)
    {
        if (e.used && e.key == key)
        {
            // TODO: переместить e.lru в начало списка order
            e.lru.unlink();
            self.order.push_front(&e.lru);
            return true;
        }
    }
    // 2. промах
    CacheEntry* slot = null;
    foreach (&e : self.entries)
    {
        if (!e.used) { slot = e; break; }
    }
    if (!slot)
    {
        // TODO: slot = самый старый (order.prev через @container_of),
        //       выписать его из списка, evictions++
        slot = @container_of(self.order.prev, CacheEntry, "lru");
        slot.lru.unlink();
        self.evictions++;
    }
    slot.key = key;
    slot.value = value;
    slot.used = true;
    self.order.push_front(&slot.lru);
    return false;
}

fn void main()
{
    // --- базовые операции
    ListNode head;
    head.init();
    assert(head.is_empty() && head.count() == 0);

    Entity[5] ents;
    foreach (i, &e : ents)
    {
        e.id = (int)i + 1;
        e.hp = 100;
        e.alive.init();
        e.dirty.init();
        assert(!e.alive.is_linked());
        head.push_back(&e.alive);
    }
    assert(head.count() == 5);
    assert(@container_of(head.next, Entity, "alive") == &ents[0], "container_of is wrong");
    assert(@container_of(&ents[3].dirty, Entity, "dirty") == &ents[3]);

    ListNode dirty;
    dirty.init();
    // помечаем изменённые: 4, 2 — порядок важен
    ents[3].hp -= 10; dirty.push_back(&ents[3].dirty);
    ents[1].hp -= 25; dirty.push_back(&ents[1].dirty);
    ents[4].hp = 0;   dirty.push_front(&ents[4].dirty);
    print_list("alive", &head, false);
    print_list("dirty", &dirty, true);

    // умершие покидают ОБА списка за O(1), без поиска
    @list_each(&head, Entity, "alive"; Entity* e)
    {
        if (e.hp <= 0)
        {
            e.alive.unlink();
            e.dirty.unlink();
        }
    };
    assert(!ents[4].alive.is_linked() && !ents[4].dirty.is_linked());
    ents[4].dirty.unlink();   // повторный unlink безопасен
    print_list("alive", &head, false);
    print_list("dirty", &dirty, true);

    // конец кадра: сбросить грязные, удаляя прямо во время обхода
    int total_hp = 0;
    @list_each(&dirty, Entity, "dirty"; Entity* e)
    {
        total_hp += e.hp;
        e.dirty.unlink();
    };
    assert(dirty.is_empty() && head.count() == 4);
    io::printfn("flushed dirty hp: %d", total_hp);

    // --- LRU
    Lru cache;
    cache.init();
    int[*] keys = { 1, 2, 3, 1, 4, 2, 5, 1, 3, 3 };
    DString log = dstring::new(mem);   // без явного аллокатора DString взял бы tmem
    defer log.free();
    foreach (k : keys) log.append(cache.touch(k, k * 100) ? 'H' : 'm');
    io::printfn("lru pattern: %s evictions=%d", log.str_view(), cache.evictions);
    io::print("lru order (fresh first):");
    @list_each(&cache.order, CacheEntry, "lru"; CacheEntry* c) { io::printf(" %d", c.key); };
    io::printn();
    assert(cache.order.count() == LRU_CAP);
}
