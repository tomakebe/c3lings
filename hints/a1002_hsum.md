hsum4: after `movhlps`+`addps`, the sum you need is given by elements 0 and 1; copy the register, `shufps xmm1, xmm1, 1` moves element 1 into position 0, then `addss`.
Main loop: the condition "i + 4 <= n" is conveniently written as `i < n - 3` (`lea rcx, [rsi - 3]`; the comparison is signed — n may be 0).
After the loop do the horizontal sum, and then the scalar tail: `addss xmm0, [rdi + rax*4]` (a scalar operand doesn't need alignment).
