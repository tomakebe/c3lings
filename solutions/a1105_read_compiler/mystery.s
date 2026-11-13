# =====================================================================
#  a1105 · mystery.s — вывод c3c -O3 (переведён в Intel-синтаксис).
#  Этот файл НЕ нужно править. Читайте его и восстанавливайте исходники
#  в main.c3.
# =====================================================================
    .intel_syntax noprefix
    .text

# uint mystery_a(uint x)
    .globl mystery_a
mystery_a:
    mov  ecx, edi
    mov  eax, 3435973837            # 0xCCCCCCCD
    imul rax, rcx
    shr  rax, 35
    lea  ecx, [rax + rax]
    lea  ecx, [rcx + rcx*4]
    sub  edi, ecx
    add  eax, edi
    ret

# int mystery_b(int x, int y)
    .globl mystery_b
mystery_b:
    lea eax, [rdi + rdi*8]
    lea eax, [rax + rsi*4]
    add eax, -7
    ret

# int mystery_c(int x)
    .globl mystery_c
mystery_c:
    lea   eax, [rdi + 3]
    test  edi, edi
    cmovns eax, edi
    sar   eax, 2
    ret

# int mystery_d(int x)
    .globl mystery_d
mystery_d:
    mov   eax, edi
    neg   eax
    cmovs eax, edi
    ret

    .section .note.GNU-stack,"",@progbits
