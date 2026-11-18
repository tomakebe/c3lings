# =====================================================================
#  a1204 · Printing a number without libc
# =====================================================================
#
#  The whole function: convert a 64-bit unsigned number into a decimal
#  string and output it with '\n' in a single write call. No printf.
#
#  Plan:
#    * the buffer is on the stack: sub rsp, 32 (enough for 20 digits + '\n');
#    * fill it FROM THE END: first '\n', then the digits, least significant
#      first:
#          digit = x % 10, x = x / 10, while x != 0
#      (do-while: for x = 0 we must get a single digit '0');
#    * div: unsigned division of rdx:rax by the operand — don't forget to
#      zero rdx before every `div` (xor edx, edx)! The remainder is in rdx.
#      (A compiler would replace division by 10 with multiplication by a
#      magic number — see chapter 11; you can do that too if you like.)
#    * '0' + digit = the ASCII code of the digit (48 + d);
#    * write(1, start_of_digits, length) and return the result of write.
#
#  This is a leaf function (it calls nothing), so stack alignment doesn't
#  matter, but rsp must be restored before ret.
#  And once again: syscall clobbers rcx and r11.
#
#  TASK: write print_u64(x /*rdi*/) -> number of bytes written.
#
    .intel_syntax noprefix
    .text
    .globl print_u64
print_u64:
    sub rsp, 32
    lea rsi, [rsp + 31]
    mov byte ptr [rsi], 10      # '\n'
    mov rax, rdi
    mov r8d, 10
1:
    xor edx, edx
    div r8                      # rax = x / 10, rdx = x % 10
    add dl, '0'
    dec rsi
    mov byte ptr [rsi], dl
    test rax, rax
    jnz 1b
    lea rdx, [rsp + 32]
    sub rdx, rsi                # length
    mov edi, 1
    mov eax, 1
    syscall
    add rsp, 32
    ret

    .section .note.GNU-stack,"",@progbits
