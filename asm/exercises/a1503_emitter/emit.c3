// =====================================================================
//  a1503 · An instruction encoder: JIT starts here
// =====================================================================
//
//  A JIT compiler needs a "miniature assembler": functions that append
//  the bytes of specific instructions to a buffer. Let's write such an
//  emitter for a few instructions with 64-bit registers.
//  Edit THIS file (emit.c3). The reference is ref.s: the same instructions
//  assembled by a real assembler; the driver compares the bytes and prints
//  a table (with your bytes shown for mismatches).
//
//  Encodings (r is the register number 0..15, see the constants below):
//
//    push r          [41] 50+(r&7)          41 = REX.B for r8..r15
//    pop r           [41] 58+(r&7)
//    mov r, imm64    REX.W|B  B8+(r&7)  imm64 (8 bytes little-endian)
//    add dst, src    REX.W|R|B  01  ModRM(reg=src, rm=dst)
//    sub dst, src    REX.W|R|B  29  ModRM(reg=src, rm=dst)
//    imul dst, src   REX.W|R|B  0F AF  ModRM(reg=dst, rm=src)
//    ret             C3
//
//    REX = 0100 W R X B = 0x40 | W<<3 | R<<2 | X<<1 | B
//        W = 1 (64 bits) -> 0x48; R = high bit of the reg field; B = of rm.
//    ModRM(reg, rm) for registers = 0xC0 | (reg&7)<<3 | (rm&7)
//
//  Why is it "reg = src" for add but "reg = dst" for imul? Opcode 01 has
//  the form "add r/m64, r64" (destination in rm), while 0F AF is
//  "imul r64, r/m64" (destination in reg). The opcode sets the direction:
//  add also has the form 03 "add r64, r/m64" — which is why the same
//  instruction can often be encoded in two ways. The assembler picks 01,
//  and so do we.
//
//  TASK: complete rex_w, pop, mov_imm64 (REX.B), add, sub, imul so that
//  all 15 rows of the table are "ok".
//
module jit;

const int RAX = 0;
const int RCX = 1;
const int RDX = 2;
const int RBX = 3;
const int RSP = 4;
const int RBP = 5;
const int RSI = 6;
const int RDI = 7;
const int R8 = 8;
const int R9 = 9;
const int R10 = 10;
const int R11 = 11;
const int R12 = 12;
const int R13 = 13;
const int R14 = 14;
const int R15 = 15;

const usz CODE_CAP = 4096;

struct Emitter
{
    char[CODE_CAP] buf;
    usz len;
}

fn void Emitter.byte(&self, int b)
{
    assert(self.len < CODE_CAP, "code buffer overflow");
    self.buf[self.len++] = (char)b;
}

fn void Emitter.u32(&self, uint v)
{
    for (int i = 0; i < 4; i++) self.byte((int)((v >> (8 * i)) & 0xFF));
}

fn void Emitter.u64(&self, ulong v)
{
    for (int i = 0; i < 8; i++) self.byte((int)((v >> (8 * i)) & 0xFF));
}

// Overwrite 4 bytes at offset pos (for jump "patches").
fn void Emitter.patch32(&self, usz pos, int v)
{
    for (usz i = 0; i < 4; i++) self.buf[pos + i] = (char)(((uint)v >> (8 * i)) & 0xFF);
}

// ModRM for "register, register": mod = 11.
fn void Emitter.modrm_rr(&self, int reg, int rm)
{
    self.byte(0xC0 | ((reg & 7) << 3) | (rm & 7));
}

fn void Emitter.ret(&self) => self.byte(0xC3);

fn void Emitter.push(&self, int r)
{
    if (r >= 8) self.byte(0x41);     // REX.B
    self.byte(0x50 + (r & 7));
}

// REX.W with the R bit (for the reg field) and the B bit (for the rm field).
// REX = 0100 W R X B; W = 1.
fn void Emitter.rex_w(&self, int reg, int rm)
{
    self.byte(0x48); // TODO: add the R bit (high bit of reg) and the B bit (high bit of rm)
}

fn void Emitter.pop(&self, int r)
{
    // TODO: like push, but with opcode 58+r
}

// mov r64, imm64   (REX.W [+B]  B8+r  imm64)
fn void Emitter.mov_imm64(&self, int r, long imm)
{
    self.byte(0x48);              // TODO: r8..r15 need the REX.B bit
    self.byte(0xB8 + (r & 7));
    self.u64((ulong)imm);
}

// add dst, src   (REX.W 01 /r: ModRM.reg = src, ModRM.rm = dst)
fn void Emitter.add(&self, int dst, int src)
{
    // TODO
}

// sub dst, src   (REX.W 29 /r)
fn void Emitter.sub(&self, int dst, int src)
{
    // TODO
}

// imul dst, src  (REX.W 0F AF /r: ModRM.reg = dst, ModRM.rm = src — the other way round!)
fn void Emitter.imul(&self, int dst, int src)
{
    // TODO
}
