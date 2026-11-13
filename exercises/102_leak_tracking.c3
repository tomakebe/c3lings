// =====================================================================
//  102 · Отслеживание утечек памяти
// =====================================================================
//
//  В C3 нет сборщика мусора и нет деструкторов, как в C++/Rust.
//  Выделили в куче — освободите сами. Забыли — утечка. Освободили
//  дважды или пользуетесь после free — повреждение кучи. Зато у C3
//  есть хорошие инструменты, чтобы такие ошибки находить.
//
//  TrackingAllocator
//  -----------------
//  Помните интерфейс Allocator? Любой аллокатор можно «обернуть»
//  отслеживающим. Он передаёт запросы внутреннему аллокатору и
//  записывает каждое выделение (размер + backtrace места выделения):
//
//      TrackingAllocator tracker;
//      tracker.init(mem);            // оборачиваем обычную кучу
//      defer tracker.free();
//      Allocator a = &tracker;       // дальше выделяем через `a`
//
//      tracker.allocation_count()        // сколько блоков живо СЕЙЧАС
//      tracker.allocated()               // сколько байт живо
//      tracker.total_allocation_count()  // сколько было выделений всего
//      tracker.max_allocated()           // пиковое потребление
//      tracker.has_leaks()               // есть ли неосвобождённое
//      tracker.fprint_report(io::stderr())!!; // отчёт со стеками вызовов
//
//  А ещё он ловит освобождение «чужого» или уже освобождённого
//  указателя (double free) — паникой с понятным сообщением.
//
//  Вот почему в стандартной библиотеке C3 функции, которые выделяют
//  память, ПРИНИМАЮТ аллокатор параметром (`s.copy(a)`,
//  `string::format(a, ...)`, `list.init(a)`) — как в Zig. Это позволяет
//  подсунуть любой аллокатор: отслеживающий, арену, временный.
//
//  Другие инструменты:
//    * @test-функции автоматически проверяются на утечки (упражнение 100);
//    * макросы `mem::@report_heap_allocs_in_scope() { ... };` и
//      `@assert_leak() { ... };` оборачивают блок кода;
//    * `c3c compile --sanitize=address` — AddressSanitizer: утечки,
//      use-after-free, выход за границы кучи;
//    * `-D VMEM_TEMP` — ловит обращения к временной памяти (tmem) после
//      конца её @pool.
//
//  Как не допускать утечек — идиомы C3:
//    * `defer` сразу после выделения:
//          int[] tmp = alloc::new_array(a, int, n);
//          defer alloc::free(a, tmp);
//      освободится на ЛЮБОМ пути выхода, включая ранний return и
//      возврат ошибки;
//    * `defer catch ...` — выполнится, только если функция выходит с
//      ошибкой (освободить то, что не успели отдать вызывающему);
//    * «владение»: структура, которая скопировала строки в свою память,
//      должна освободить их в своём .free(). Освобождение контейнера
//      (List.free) освобождает только ЕГО буфер, а не то, на что
//      указывают элементы;
//    * короткоживущие данные — во временный аллокатор: `@pool() {...};`
//      и tmem, тогда освобождать поштучно не нужно вовсе.
//
//  ЗАДАЧА: в программе три ошибки владения памятью. Найдите их по
//  выводу (live allocations должно быть 0 после каждой фазы) и
//  почините: одна в Inventory, одна в make_report, одна в main (кто-то
//  не выполнил обязанность «освобождает вызывающий»).
//
//  Ожидаемый вывод:
//      inventory: 5 items, 23 total qty
//      after inventory: live allocations = 0
//      report: 1, 3, 4, 7, 9
//      after report: live allocations = 0
//      bad input rejected: report::NEGATIVE_VALUE
//      after error: live allocations = 0
//      no leaks
//
module report;
import std::io, std::collections::list;

struct Item
{
    String name;     // принадлежит Inventory (скопировано в inv.alloc)
    int qty;
}

struct Inventory
{
    Allocator alloc;
    List{Item} items;
}

fn void Inventory.init(&self, Allocator a)
{
    self.alloc = a;
    self.items.init(a);
}

fn void Inventory.add(&self, String name, int qty)
{
    self.items.push({ name.copy(self.alloc), qty });
}

fn void Inventory.free(&self)
{
    self.items.free();
}

excuse NEGATIVE_VALUE;

<*
 Отсортированные значения через запятую. Результат выделен в `a`,
 освобождает вызывающий.
*>
fn String? make_report(Allocator a, int[] values)
{
    int[] sorted = alloc::new_array(a, int, values.len);
    foreach (i, v : values)
    {
        if (v < 0) return NEGATIVE_VALUE~;
        sorted[i] = v;
    }
    // сортировка вставками
    for (usz i = 1; i < sorted.len; i++)
    {
        for (usz j = i; j > 0 && sorted[j - 1] > sorted[j]; j--)
        {
            @swap(sorted[j - 1], sorted[j]);
        }
    }
    DString out;
    out.init(a);
    foreach (i, v : sorted)
    {
        if (i > 0) out.append(", ");
        out.appendf("%d", v);
    }
    String result = out.copy_str(a);
    out.free();
    return result;
}

fn void main()
{
    TrackingAllocator tracker;
    tracker.init(mem);
    defer tracker.free();
    Allocator a = &tracker;

    // ---- фаза 1
    {
        Inventory inv;
        inv.init(a);
        inv.add("apple", 5);
        inv.add("pear", 3);
        inv.add("plum", 10);
        inv.add("kiwi", 1);
        inv.add("lime", 4);
        int qty = 0;
        foreach (item : inv.items) qty += item.qty;
        io::printfn("inventory: %d items, %d total qty", inv.items.len(), qty);
        inv.free();
    }
    io::printfn("after inventory: live allocations = %d", tracker.allocation_count());

    // ---- фаза 2
    {
        String r = make_report(a, { 7, 3, 9, 1, 4 })!!;
        io::printfn("report: %s", r);
    }
    io::printfn("after report: live allocations = %d", tracker.allocation_count());

    // ---- фаза 3
    {
        String? r = make_report(a, { 5, -2, 8 });
        if (catch err = r) io::printfn("bad input rejected: %s", err);
    }
    io::printfn("after error: live allocations = %d", tracker.allocation_count());

    if (tracker.has_leaks())
    {
        tracker.fprint_report(io::stderr())!!;
        io::printn("LEAKS!");
    }
    else
    {
        io::printn("no leaks");
    }
}
