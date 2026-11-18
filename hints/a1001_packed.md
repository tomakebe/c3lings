`addss` is scalar single (one element), `addps` is packed single (all four).
Broadcasting a scalar: `shufps xmm0, xmm0, 0` — all four lanes take element 0.
add_arrays: index in rax, addresses `[rsi + rax*4]`, load with `movups` (not `movaps` — the addresses are not aligned; and not `addps xmm0, [mem]` — that also requires alignment), step 4.
