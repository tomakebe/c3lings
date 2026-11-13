// Тестовый стенд упражнения a0706. НЕ редактируйте этот файл — правьте list.s.
import std::io;

struct Item
{
    int key;        // смещение 0
    Item* next;     // смещение 8 (после 4 байт padding)
    long payload;   // смещение 16
}

extern fn Item* asm_reverse_list(Item* head);
extern fn Item* asm_find(Item* head, int key);
extern fn long asm_sum_payload(Item* head);

fn void print_list(Item* p)
{
    io::print("[");
    while (p)
    {
        io::printf("%d", p.key);
        if (p.next) io::print(" -> ");
        p = p.next;
    }
    io::printn("]");
}

fn void main()
{
    Item[5] items;
    for (int i = 0; i < 5; i++)
    {
        items[i].key = i + 1;
        items[i].payload = (long)(i + 1) * 1_000_000_000;
        items[i].next = i < 4 ? &items[i + 1] : null;
    }
    Item* head = &items[0];
    print_list(head);
    assert(asm_find(head, 3) == &items[2], "asm_find(3)");
    assert(asm_find(head, 9) == null, "asm_find(9) должна вернуть null");
    assert(asm_find(null, 1) == null, "asm_find(null, 1) должна вернуть null");
    assert(asm_sum_payload(head) == 15_000_000_000, "asm_sum_payload = %d", asm_sum_payload(head));
    head = asm_reverse_list(head);
    assert(head == &items[4], "после разворота голова — последний элемент");
    print_list(head);
    assert(asm_reverse_list(null) == null, "asm_reverse_list(null)");
    Item single = { 42, null, 0 };
    assert(asm_reverse_list(&single) == &single && single.next == null, "список из одного элемента");
    io::printfn("found=%d sum=%d", asm_find(head, 3).key, asm_sum_payload(head));
}
