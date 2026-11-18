After `rdtsc` the low 32 bits are in eax (the upper bits of rax are already zeroed) and the high bits are in edx: `shl rdx, 32; or rax, rdx`.
read_tscp: `rdtscp`, then `lfence`, save ecx with `mov dword ptr [rdi], ecx`, and assemble the result the same way.
