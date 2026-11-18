# =====================================================================
#  a0101 · Your first assembly function
# =====================================================================
#
#  Welcome to the second track! Here every exercise is a directory:
#  it contains a C3 driver main.c3 (the test harness — DON'T touch it)
#  and one or more .s files, which are yours to edit. The runner builds
#  the .s files with `cc -c` (that's GNU as) and links them with the driver.
#
#  We write in Intel syntax: "destination, source".
#
#      mov eax, 5        # eax = 5
#
#  The lines of the file:
#    .intel_syntax noprefix   — Intel syntax without % before registers;
#    .text                    — code follows;
#    .globl asm_answer        — make the label visible to the linker
#                               (otherwise C3 won't find the function);
#    asm_answer:              — label = address of the function's first instruction;
#    ret                      — return to wherever we were called from.
#  The last line (.note.GNU-stack) tells the linker that our code does
#  not need an executable stack. Just copy it to the end of the file.
#
#  Comments in GNU as for x86 start with `#`.
#
#  Under the System V ABI convention (Linux, x86-64) a function returns
#  an integer value in the rax register. For a 32-bit `int` its lower
#  half, eax, is used. The driver declared the function like this:
#
#      extern fn int asm_answer();
#
#  and will read the result from eax right after `ret`.
#
#  TASK: the function must return 42. The program will print
#      asm_answer() = 42
#
    .intel_syntax noprefix
    .text

    .globl asm_answer
asm_answer:
    mov eax, 42             # TODO: should return 42
    ret

    .section .note.GNU-stack,"",@progbits
