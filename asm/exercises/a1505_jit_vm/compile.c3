// =====================================================================
//  a1505 · ФИНАЛ: JIT для скриптового языка с циклами и вызовами хоста
// =====================================================================
//
//  Байт-код (vm.c3) — стековая машина, как в a1504, плюс локальные
//  переменные, сравнение, переходы и вызов функций хоста (C3) из
//  скрипта. Ровно так устроены скриптовые языки движков (Lua, Wren,
//  байт-код Unreal Blueprints) — а их JIT-ы (LuaJIT) делают то же, что
//  вы сейчас, только гораздо умнее.
//
//  Кадр сгенерированной функции:
//
//      push rbp            55
//      mov  rbp, rsp       48 89 E5
//      push rdi            57              ; x хранится в [rbp-8]: rdi
//                                          ; испортится при вызове хоста
//      sub  rsp, 56        48 83 EC 38     ; 7 локальных: local[i] = [rbp - 16 - 8*i]
//
//  Остальное уже сгенерировано, кроме ЧЕТЫРЁХ мест (TODO):
//
//  1. LT:  pop rcx ; pop rax ; cmp rax, rcx ; setl al ; movzx eax, al ; push rax
//          cmp rax, rcx = 48 39 C8,  setl al = 0F 9C C0,  movzx eax, al = 0F B6 C0
//
//  2. JMP t:  E9 rel32
//     JZ t:   pop rax ; test rax, rax (48 85 C0) ; jz rel32 (0F 84 rel32)
//     rel32 отсчитывается от КОНЦА инструкции перехода:
//         rel32 = (смещение кода инструкции t) - (смещение после rel32)
//     Но при переходе ВПЕРЁД код инструкции t ещё не сгенерирован!
//     Классическое решение — «заплатки» (backpatching): пишем 4 нулевых
//     байта, запоминаем (позиция rel32, индекс цели) в списке fixups,
//     а после генерации всей программы, когда известны смещения всех
//     инструкций (массив label), дописываем: e.patch32(pos, label[t] - (pos + 4)).
//
//  3. CALL k — вызов функции C3 host_table[k](v):
//         pop rdi                    5F
//         mov rax, rsp               48 89 E0     ; запомнить rsp
//         and rsp, -16               48 83 E4 F0  ; выровнять по ABI
//         push rax                   50           ; сохранить старый rsp...
//         push rax                   50           ; ...дважды: rsp остаётся кратным 16
//         mov rax, <адрес функции>   e.mov_imm64(RAX, (long)(uptr)host_table[k])
//         call rax                   FF D0
//         pop rsp                    5C           ; [rsp] = старый rsp
//         push rax                   50           ; результат на стек байт-кода
//     Глубина стека байт-кода в момент вызова произвольна, поэтому rsp
//     выравнивается динамически. Хост-функция может портить rdi, rsi,
//     rcx, ... — нам это не мешает: x мы сохранили в кадре, а стек
//     байт-кода живёт в памяти.
//
//  4. После цикла — пройти по fixups и пропатчить переходы.
//
//  ЗАДАЧА: заполните четыре TODO. Драйвер сравнивает JIT с интерпретатором
//  на нескольких программах (факториал циклом, сумма квадратов через
//  вызов хоста, трассировка, ветвление).
//
//  Куда дальше: распределение регистров вместо стека, свёртка констант,
//  inline-кеши, деоптимизация... см. asm/docs/15_jit.md.
//
module jit;

struct Fixup
{
    usz pos;        // где лежит rel32
    long target;    // индекс инструкции байт-кода, куда прыгаем
}

fn void compile(Emitter* e, Instr[] prog)
{
    usz[256] label;          // label[i] — смещение машинного кода инструкции i
    Fixup[256] fixups;
    usz nfix = 0;
    assert(prog.len <= 256);

    // пролог
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
                // TODO 1
                unreachable("TODO: LT");
            case JZ:
                // TODO 2
                unreachable("TODO: JZ");
            case JMP:
                // TODO 2
                unreachable("TODO: JMP");
            case CALL:
                // TODO 3
                unreachable("TODO: CALL");
            case RET:
                e.pop(RAX);
                e.byte(0xC9);                                    // leave
                e.ret();
        }
    }
    // TODO 4: пропатчить переходы
}
