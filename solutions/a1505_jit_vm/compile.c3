// =====================================================================
//  a1505 · FINALE: a JIT for a scripting language with loops and host calls
// =====================================================================
//
//  The bytecode (vm.c3) is a stack machine, as in a1504, plus local
//  variables, comparison, jumps, and calls to host (C3) functions from
//  the script. This is exactly how engine scripting languages are built
//  (Lua, Wren, Unreal Blueprints bytecode) — and their JITs (LuaJIT) do
//  the same thing you are doing now, only much more cleverly.
//
//  The frame of the generated function:
//
//      push rbp            55
//      mov  rbp, rsp       48 89 E5
//      push rdi            57              ; x is kept in [rbp-8]: rdi
//                                          ; gets clobbered by a host call
//      sub  rsp, 56        48 83 EC 38     ; 7 locals: local[i] = [rbp - 16 - 8*i]
//
//  Everything else is already generated, except for FOUR places (TODO):
//
//  1. LT:  pop rcx ; pop rax ; cmp rax, rcx ; setl al ; movzx eax, al ; push rax
//          cmp rax, rcx = 48 39 C8,  setl al = 0F 9C C0,  movzx eax, al = 0F B6 C0
//
//  2. JMP t:  E9 rel32
//     JZ t:   pop rax ; test rax, rax (48 85 C0) ; jz rel32 (0F 84 rel32)
//     rel32 is measured from the END of the jump instruction:
//         rel32 = (code offset of instruction t) - (offset just after rel32)
//     But for a FORWARD jump the code for instruction t has not been
//     generated yet! The classic solution is backpatching: write 4 zero
//     bytes, record (position of rel32, target index) in the fixups list,
//     and after the whole program has been generated, when the offsets of
//     all instructions are known (the label array), fill them in:
//     e.patch32(pos, label[t] - (pos + 4)).
//
//  3. CALL k — call the C3 function host_table[k](v):
//         pop rdi                    5F
//         mov rax, rsp               48 89 E0     ; remember rsp
//         and rsp, -16               48 83 E4 F0  ; align per the ABI
//         push rax                   50           ; save the old rsp...
//         push rax                   50           ; ...twice: rsp stays a multiple of 16
//         mov rax, <function address> e.mov_imm64(RAX, (long)(uptr)host_table[k])
//         call rax                   FF D0
//         pop rsp                    5C           ; [rsp] = old rsp
//         push rax                   50           ; result onto the bytecode stack
//     The depth of the bytecode stack at the moment of the call is
//     arbitrary, so rsp is aligned dynamically. The host function may
//     clobber rdi, rsi, rcx, ... — that does not bother us: we saved x in
//     the frame, and the bytecode stack lives in memory.
//
//  4. After the loop — walk the fixups and patch the jumps.
//
//  TASK: fill in the four TODOs. The driver compares the JIT against the
//  interpreter on several programs (a loop-based factorial, a sum of
//  squares via a host call, tracing, branching).
//
//  Where to go next: register allocation instead of a stack, constant
//  folding, inline caches, deoptimization... see asm/docs/15_jit.md.
//
module jit;

struct Fixup
{
    usz pos;        // where the rel32 is located
    long target;    // index of the bytecode instruction we jump to
}

fn void compile(Emitter* e, Instr[] prog)
{
    usz[256] label;          // label[i] is the machine-code offset of instruction i
    Fixup[256] fixups;
    usz nfix = 0;
    assert(prog.len <= 256);

    // prologue
    e.byte(0x55);
    e.byte(0x48); e.byte(0x89); e.byte(0xE5);
    e.byte(0x57);
    e.byte(0x48); e.byte(0x83); e.byte(0xEC); e.byte(0x38);

    foreach (i, ins : prog)
    {
        label[i] = e.len;
        switch (ins.op)
        {
            case CONST:
                e.mov_imm64(RAX, ins.arg);
                e.push(RAX);
            case ARG:
                e.byte(0xFF); e.byte(0x75); e.byte(0xF8);        // push qword [rbp - 8]
            case LOAD:
                e.byte(0xFF); e.byte(0x75); e.byte((int)(-16 - 8 * ins.arg) & 0xFF);   // push qword [rbp + disp8]
            case STORE:
                e.byte(0x8F); e.byte(0x45); e.byte((int)(-16 - 8 * ins.arg) & 0xFF);   // pop qword [rbp + disp8]
            case ADD:
                e.pop(RCX); e.pop(RAX); e.add(RAX, RCX); e.push(RAX);
            case SUB:
                e.pop(RCX); e.pop(RAX); e.sub(RAX, RCX); e.push(RAX);
            case MUL:
                e.pop(RCX); e.pop(RAX); e.imul(RAX, RCX); e.push(RAX);
            case LT:
                e.pop(RCX); e.pop(RAX);
                e.byte(0x48); e.byte(0x39); e.byte(0xC8);       // cmp rax, rcx
                e.byte(0x0F); e.byte(0x9C); e.byte(0xC0);       // setl al
                e.byte(0x0F); e.byte(0xB6); e.byte(0xC0);       // movzx eax, al
                e.push(RAX);
            case JZ:
                e.pop(RAX);
                e.byte(0x48); e.byte(0x85); e.byte(0xC0);       // test rax, rax
                e.byte(0x0F); e.byte(0x84);                     // jz rel32
                fixups[nfix++] = { e.len, ins.arg };
                e.u32(0);
            case JMP:
                e.byte(0xE9);                                   // jmp rel32
                fixups[nfix++] = { e.len, ins.arg };
                e.u32(0);
            case CALL:
                e.byte(0x5F);                                   // pop rdi
                e.byte(0x48); e.byte(0x89); e.byte(0xE0);       // mov rax, rsp
                e.byte(0x48); e.byte(0x83); e.byte(0xE4); e.byte(0xF0);   // and rsp, -16
                e.push(RAX);
                e.push(RAX);
                e.mov_imm64(RAX, (long)(uptr)host_table[ins.arg]);
                e.byte(0xFF); e.byte(0xD0);                     // call rax
                e.byte(0x5C);                                   // pop rsp
                e.push(RAX);
            case RET:
                e.pop(RAX);
                e.byte(0xC9);                                    // leave
                e.ret();
        }
    }
    for (usz k = 0; k < nfix; k++)
    {
        Fixup f = fixups[k];
        e.patch32(f.pos, (int)((long)label[f.target] - (long)(f.pos + 4)));
    }
}
