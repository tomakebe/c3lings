For integer -> double: `cvtsi2sd xmm0, rdi`. Double -> integer dropping the fraction: `cvttsd2si` (the extra t = truncate).
`cvtsd2si` rounds according to the MXCSR mode — to nearest even by default, which is exactly what round_to_long expects.
average: a loop with `movsxd rdx, dword ptr [rdi + rcx*4]` and `add rax, rdx`; then both values go into xmm via cvtsi2sd and `divsd xmm0, xmm1`.
