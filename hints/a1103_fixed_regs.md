mulq puts the low half in rax and the high half in rdx.
muldiv: after `mulq b`, rdx:rax holds the 128-bit product — exactly what `divq c` expects. The quotient is in $rax.
rdtsc: `rdtsc; movl lo, $eax; movl hi, $edx;` — the variables must be 32-bit (uint), since the suffix is l.
