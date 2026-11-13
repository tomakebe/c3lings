4x4: скопируйте строки (movdqa), чтобы не потерять их, затем `punpckldq/punpckhdq` для пар строк (a,b) и (c,d), потом `punpcklqdq/punpckhqdq` между результатами — схема в шапке.
Запись: dst, dst+stride, dst+2*stride, dst+3*stride (stride уже в байтах).
transpose: блок (bi, bj) src начинается с src + (bi*n + bj)*4 и переходит в dst + (bj*n + bi)*4; оба stride = n. Счётчики и указатели храните в callee-saved регистрах, rsp перед call кратен 16.
