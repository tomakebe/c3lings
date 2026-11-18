Floating-point arguments are numbered separately from integer ones: the first double is xmm0, the second is xmm1, and so on.
`subsd xmm0, xmm1` means xmm0 = xmm0 - xmm1. The result must end up in xmm0.
lerp: everything is float, so `subss`, `mulss`, `addss`.
mix_args: y is the second floating-point argument (xmm1) and it is a float; first `cvtss2sd xmm1, xmm1`, then `addsd`.
