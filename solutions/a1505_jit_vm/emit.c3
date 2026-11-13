// Готовый эмиттер из a1503. Этот файл НЕ нужно править.
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

// Перезаписать 4 байта по смещению pos (для «заплаток» переходов).
fn void Emitter.patch32(&self, usz pos, int v)
{
    for (usz i = 0; i < 4; i++) self.buf[pos + i] = (char)(((uint)v >> (8 * i)) & 0xFF);
}

// ModRM для «регистр, регистр»: mod = 11.
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

// REX.W с битами R (для поля reg) и B (для поля rm).
fn void Emitter.rex_w(&self, int reg, int rm)
{
    self.byte(0x48 | ((reg >> 3) << 2) | (rm >> 3));
}

fn void Emitter.pop(&self, int r)
{
    if (r >= 8) self.byte(0x41);
    self.byte(0x58 + (r & 7));
}

// mov r64, imm64   (REX.W [+B]  B8+r  imm64)
fn void Emitter.mov_imm64(&self, int r, long imm)
{
    self.byte(0x48 | (r >> 3));
    self.byte(0xB8 + (r & 7));
    self.u64((ulong)imm);
}

// add dst, src   (REX.W 01 /r: ModRM.reg = src, ModRM.rm = dst)
fn void Emitter.add(&self, int dst, int src)
{
    self.rex_w(src, dst);
    self.byte(0x01);
    self.modrm_rr(src, dst);
}

// sub dst, src   (REX.W 29 /r)
fn void Emitter.sub(&self, int dst, int src)
{
    self.rex_w(src, dst);
    self.byte(0x29);
    self.modrm_rr(src, dst);
}

// imul dst, src  (REX.W 0F AF /r: ModRM.reg = dst, ModRM.rm = src)
fn void Emitter.imul(&self, int dst, int src)
{
    self.rex_w(dst, src);
    self.byte(0x0F);
    self.byte(0xAF);
    self.modrm_rr(dst, src);
}

// neg r   (REX.W F7 /3)
fn void Emitter.neg(&self, int r)
{
    self.rex_w(0, r);
    self.byte(0xF7);
    self.modrm_rr(3, r);
}
