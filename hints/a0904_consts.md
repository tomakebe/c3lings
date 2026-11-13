Память с маской адресуется относительно rip: `andpd xmm0, xmmword ptr [rip + abs_mask]`.
vec2_length: два `mulsd` (квадраты), `addsd`, `sqrtsd xmm0, xmm0`.
horner: сохраните x в xmm1 (`movapd xmm1, xmm0`), начните с c[n-1] = `[rdi + rsi*8 - 8]` и идите индексом вниз до 0 включительно.
pi: в `.rodata` добавьте `pi: .double 3.141592653589793` и используйте `mulsd xmm0, qword ptr [rip + pi]`.
