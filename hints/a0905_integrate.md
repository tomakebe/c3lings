Все xmm портятся вызовом, поэтому a, h и сумму храните на стеке: `movsd qword ptr [rsp + 8], xmm1` и т.п.
f, n и счётчик i — в rbx, r12, r13 (сохраните их push'ами в прологе).
Выравнивание: 8 (адрес возврата) + 3 push = 32, плюс `sub rsp, 32` — rsp кратен 16 перед `call rbx`.
Аргумент для f: `cvtsi2sd xmm0, r13`, `addsd xmm0, [rip + half]`, `mulsd` на h, `addsd` a.
