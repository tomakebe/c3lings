# =====================================================================
#  a0302 · Ветвления: if / else if / else
# =====================================================================
#
#  Как компилятор переводит
#
#      if (x < 0) return -1;
#      else if (x == 0) return 0;
#      else return 1;
#
#  Каждое условие превращается в «cmp/test + переход ЕСЛИ НЕ выполнено»
#  на следующий блок (или переход ЕСЛИ выполнено — на нужный блок):
#
#          test rdi, rdi        # флаги как от rdi & rdi: SF = знак, ZF = ноль
#          js   .Lneg           # SF=1 -> отрицательное
#          jz   .Lzero          # ZF=1 -> ноль
#          ...                  # иначе — положительное
#
#  `test a, b` — это `and` без записи результата. `test rdi, rdi` —
#  стандартная идиома «сравнить с нулём»: короче, чем `cmp rdi, 0`.
#  Переход `jz` — то же, что `je`, `jnz` — то же, что `jne` (одна
#  инструкция, два имени). `js`/`jns` — по флагу знака.
#
#  Метки, начинающиеся с `.L`, — локальные для файла: они не попадают
#  в таблицу символов объектника и не мешают в objdump/gdb.
#
#  Каждая ветка должна заканчиваться либо `ret`, либо `jmp` — иначе
#  выполнение «провалится» в следующий блок (fall-through).
#
#  ЗАДАЧА:
#    asm_sign(x)          -> -1, 0 или 1
#    asm_clamp(x, lo, hi) -> lo, если x < lo; hi, если x > hi; иначе x
#                            (все числа знаковые, lo <= hi)
#  Программа напечатает
#      sign=-1 0 1 clamp=0 5 10
#
    .intel_syntax noprefix
    .text

    .globl asm_sign
asm_sign:
    test rdi, rdi
    js .Lneg
    jz .Lzero
    mov eax, 1
    ret
.Lneg:
    mov rax, -1
    ret
.Lzero:
    xor eax, eax
    ret

    .globl asm_clamp
asm_clamp:
    mov rax, rdi
    cmp rdi, rsi
    jl .Llow
    cmp rdi, rdx
    jg .Lhigh
    ret
.Llow:
    mov rax, rsi
    ret
.Lhigh:
    mov rax, rdx
    ret

    .section .note.GNU-stack,"",@progbits
