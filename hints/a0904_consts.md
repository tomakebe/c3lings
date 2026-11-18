Memory holding the mask is addressed relative to rip: `andpd xmm0, xmmword ptr [rip + abs_mask]`.
vec2_length: two `mulsd` (squares), `addsd`, `sqrtsd xmm0, xmm0`.
horner: save x in xmm1 (`movapd xmm1, xmm0`), start with c[n-1] = `[rdi + rsi*8 - 8]` and walk the index down to 0 inclusive.
pi: in `.rodata` add `pi: .double 3.141592653589793` and use `mulsd xmm0, qword ptr [rip + pi]`.
