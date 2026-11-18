Every xmm register is clobbered by a call, so keep a, h and the sum on the stack: `movsd qword ptr [rsp + 8], xmm1`, etc.
f, n and the counter i go in rbx, r12, r13 (save them with pushes in the prologue).
Alignment: 8 (return address) + 3 pushes = 32, plus `sub rsp, 32` — rsp is a multiple of 16 before `call rbx`.
The argument for f: `cvtsi2sd xmm0, r13`, `addsd xmm0, [rip + half]`, `mulsd` by h, `addsd` a.
