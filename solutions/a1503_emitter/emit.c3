// =====================================================================
//  a1503 · Кодировщик инструкций: JIT начинается здесь
// =====================================================================
//
//  JIT-компилятору нужен «ассемблер в миниатюре»: функции, которые
//  дописывают в буфер байты конкретных инструкций. Напишем такой
//  эмиттер для нескольких инструкций с 64-битными регистрами.
//  Правьте ЭТОТ файл (emit.c3). Эталон — ref.s: те же инструкции,
//  собранные настоящим ассемблером; драйвер сравнивает байты и печатает
//  таблицу (с вашими байтами для несовпадающих).
//
//  Кодировки (r — номер регистра 0..15, см. константы ниже):
//
//    push r          [41] 50+(r&7)          41 = REX.B для r8..r15
//    pop r           [41] 58+(r&7)
//    mov r, imm64    REX.W|B  B8+(r&7)  imm64 (8 байт little-endian)
//    add dst, src    REX.W|R|B  01  ModRM(reg=src, rm=dst)
//    sub dst, src    REX.W|R|B  29  ModRM(reg=src, rm=dst)
//    imul dst, src   REX.W|R|B  0F AF  ModRM(reg=dst, rm=src)
//    ret             C3
//
//    REX = 0100 W R X B = 0x40 | W<<3 | R<<2 | X<<1 | B
//        W = 1 (64 бита) -> 0x48; R = старший бит поля reg; B = rm.
//    ModRM(reg, rm) для регистров = 0xC0 | (reg&7)<<3 | (rm&7)
//
//  Почему у add «reg = src», а у imul «reg = dst»? У опкода 01 форма
//  «add r/m64, r64» (приёмник в rm), у 0F AF — «imul r64, r/m64»
//  (приёмник в reg). Направление задаёт опкод: у add есть и форма 03
//  «add r64, r/m64» — поэтому одну инструкцию часто можно закодировать
//  двумя способами. Ассемблер выбирает 01, и мы тоже.
//
//  ЗАДАЧА: допишите rex_w, pop, mov_imm64 (REX.B), add, sub, imul так,
//  чтобы все 15 строк таблицы были «ok».
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
// REX = 0100 W R X B; W = 1.
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

// imul dst, src  (REX.W 0F AF /r: ModRM.reg = dst, ModRM.rm = src — наоборот!)
fn void Emitter.imul(&self, int dst, int src)
{
    self.rex_w(dst, src);
    self.byte(0x0F);
    self.byte(0xAF);
    self.modrm_rr(dst, src);
}
