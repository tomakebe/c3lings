4x4: copy the rows (movdqa) so you don't lose them, then `punpckldq/punpckhdq` on the row pairs (a,b) and (c,d), then `punpcklqdq/punpckhqdq` between the results — see the diagram in the header.
Stores: dst, dst+stride, dst+2*stride, dst+3*stride (stride is already in bytes).
transpose: block (bi, bj) of src starts at src + (bi*n + bj)*4 and goes to dst + (bj*n + bi)*4; both strides = n. Keep counters and pointers in callee-saved registers; rsp must be a multiple of 16 before call.
