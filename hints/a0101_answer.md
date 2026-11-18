A function's return value is whatever is in `eax`/`rax` at the moment of `ret`.
Right now 0 is put there. Change the immediate operand in the `mov`.
