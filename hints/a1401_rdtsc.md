После `rdtsc` младшие 32 бита в eax (старшие биты rax уже обнулены), старшие — в edx: `shl rdx, 32; or rax, rdx`.
read_tscp: `rdtscp`, затем `lfence`, сохраните ecx: `mov dword ptr [rdi], ecx`, и соберите результат так же.
