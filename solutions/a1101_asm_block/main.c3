// =====================================================================
//  a1101 · C3 inline assembly: the asm { ... } block
// =====================================================================
//
//  In this chapter you edit the .c3 file ITSELF: the assembly lives inside
//  C3 functions. C3 has two kinds of inline assembly:
//
//    asm("nop");        — the string is passed to LLVM as is. The compiler
//                         knows nothing about what it reads and clobbers.
//                         Good for nop/pause/int3, nothing more.
//
//    asm { ... }        — a "structured" block. The compiler parses the
//                         instructions ITSELF, understands which variables
//                         are read and written, which registers and flags
//                         get clobbered, and generates correct constraints
//                         for LLVM.
//
//  The block syntax is a hybrid:
//    * AT&T-style mnemonics, WITH A SIZE SUFFIX: movl (32 bits),
//      movq (64), addl, subq, xorl, ...
//    * but the operand order is Intel's: DESTINATION FIRST:
//          addl r, b;     // r += b
//    * registers take a $ prefix: $eax, $rdx, $xmm0;
//    * operands can be C3 variables, by name: movl r, a;
//    * memory is [p], [p + 4], [p + i * 4 + 8] (p is a pointer variable);
//    * the variable's size must match the suffix: movl requires
//      int/uint, movq requires long/ulong/a pointer. Otherwise you get the
//      compile error "'ulong' is not supported in this position".
//    * every instruction ends with `;`.
//
//      fn int add(int a, int b)
//      {
//          int r;
//          asm
//          {
//              movl r, a;
//              addl r, b;
//          }
//          return r;
//      }
//
//  Only a subset of instructions is supported (the full list is printed by
//  `c3c compile --list-asm file.c3`). For example, there is no and, shl,
//  imul, cmp, jmp — C3 already generates excellent code for those.
//
//  TASK: fix the three functions so that the checks pass.
//
import std::io;

// r = a + b
fn int add(int a, int b)
{
    int r;
    asm
    {
        movl r, a;
        addl r, b;
    }
    return r;
}

// r = a - b  (64 bits)
fn long sub64(long a, long b)
{
    long r;
    asm
    {
        movq r, a;
        subq r, b;
    }
    return r;
}

// r = ~(a ^ b) + 1   (that is, -(a ^ b))
fn uint xor_neg(uint a, uint b)
{
    uint r = a;
    asm
    {
        xorl r, b;
        notl r;
        incl r;
    }
    return r;
}

fn void main()
{
    assert(add(2, 40) == 42);
    assert(add(-5, 3) == -2);
    assert(sub64(10_000_000_000, 1) == 9_999_999_999);
    assert(sub64(3, 10) == -7);
    assert(xor_neg(0b1100, 0b1010) == (uint)-(int)0b0110);
    io::printfn("add(2, 40)         = %d", add(2, 40));
    io::printfn("sub64(1e10, 1)     = %d", sub64(10_000_000_000, 1));
    io::printfn("xor_neg(12, 10)    = %d", (int)xor_neg(12, 10));
}
