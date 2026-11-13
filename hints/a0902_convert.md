Для целого -> double: `cvtsi2sd xmm0, rdi`. Double -> целое с отбрасыванием дроби: `cvttsd2si` (лишняя t = truncate).
`cvtsd2si` округляет по режиму MXCSR — по умолчанию к ближайшему чётному, это как раз то, что ждёт round_to_long.
average: цикл с `movsxd rdx, dword ptr [rdi + rcx*4]` и `add rax, rdx`; потом обе величины в xmm через cvtsi2sd и `divsd xmm0, xmm1`.
