fetch_add: `mov eax, esi` and `lock xadd dword ptr [rdi], eax` — afterwards eax holds the old value.
inc64: the same with one in rax (`lock xadd qword ptr [rdi], rax`), and then `inc rax` to return the new value.
