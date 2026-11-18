# =====================================================================
#  a1404 · Alignment: prologue, aligned body, tail
# =====================================================================
#
#  Loads and stores that cross a cache line boundary (64 bytes) cost
#  more: the processor has to touch two lines. A 32-byte ymm store to a
#  random address crosses a boundary half the time. And streaming
#  ("non-temporal") vmovntdq stores and aligned vmovdqa stores outright
#  require an address that is a multiple of 32.
#
#  That is why fast memset/memcpy are structured like this:
#    1. PROLOGUE: store elements one at a time until the address becomes
#       a multiple of 32 (or until we run out of elements);
#    2. BODY: aligned vmovdqa stores of 8 uint32 each;
#    3. TAIL: the remaining < 8 elements, scalar.
#
#      test dil, 31      ; is the address a multiple of 32? (low 5 bits == 0)
#
#  Broadcast the value to 8 lanes: vmovd xmm0, esi; vpbroadcastd ymm0, xmm0.
#
#  For huge fills (larger than the last-level cache) vmovntdq is better:
#  the data is written around the cache and doesn't evict useful lines.
#  Then an sfence at the end is mandatory — non-temporal stores are
#  weakly ordered.
#
#  TASK: fill_u32(dst /*rdi*/, v /*esi*/, n /*rdx*/) — store v into
#  dst[0..n-1]. dst is a multiple of 4, but not necessarily of 32. Use
#  vmovdqa in the body (if you get the alignment wrong you'll get a
#  segfault — that's the check). Don't forget vzeroupper.
#
    .intel_syntax noprefix
    .text
    .globl fill_u32
fill_u32:
    # 1. prologue
    jmp 2f
1:
    mov [rdi], esi
    add rdi, 4
    dec rdx
2:
    test rdx, rdx
    jz 9f
    test dil, 31
    jnz 1b
    # 2. body
    vmovd xmm0, esi
    vpbroadcastd ymm0, xmm0
    jmp 4f
3:
    vmovdqa [rdi], ymm0
    add rdi, 32
    sub rdx, 8
4:
    cmp rdx, 8
    jge 3b
    vzeroupper
    # 3. tail
    jmp 6f
5:
    mov [rdi], esi
    add rdi, 4
    dec rdx
6:
    test rdx, rdx
    jnz 5b
9:
    ret

    .section .note.GNU-stack,"",@progbits
