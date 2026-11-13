// Тестовый стенд упражнения a0605. НЕ редактируйте этот файл и abi_check.s —
// правьте tree.s.
import std::io;

struct Node
{
    long value;     // смещение 0
    Node* left;     // смещение 8
    Node* right;    // смещение 16
}

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn long asm_tree_sum(Node* n);
extern fn long asm_tree_depth(Node* n);

fn void main()
{
    //            10
    //          /    \
    //        -3      7
    //        / \      \
    //       1   4      100
    //                  /
    //                -50
    Node n50  = { -50, null, null };
    Node n100 = { 100, &n50, null };
    Node n1   = { 1, null, null };
    Node n4   = { 4, null, null };
    Node nm3  = { -3, &n1, &n4 };
    Node n7   = { 7, null, &n100 };
    Node root = { 10, &nm3, &n7 };

    long s = abi_call(&asm_tree_sum, (long)&root, 0, 0, 0);
    assert(abi_errors() == 0, "asm_tree_sum нарушила ABI: код %d", abi_errors());
    assert(s == 69, "asm_tree_sum = %d", s);
    long d = abi_call(&asm_tree_depth, (long)&root, 0, 0, 0);
    assert(abi_errors() == 0, "asm_tree_depth нарушила ABI: код %d", abi_errors());
    assert(d == 4, "asm_tree_depth = %d", d);
    assert(asm_tree_sum(null) == 0, "asm_tree_sum(null) = %d", asm_tree_sum(null));
    assert(asm_tree_depth(null) == 0, "asm_tree_depth(null) = %d", asm_tree_depth(null));
    assert(asm_tree_depth(&n4) == 1, "asm_tree_depth(лист) = %d", asm_tree_depth(&n4));
    io::printfn("sum=%d depth=%d sub_sum=%d", s, d, asm_tree_sum(&n7));
}
