fetch_add: `mov eax, esi` и `lock xadd dword ptr [rdi], eax` — после неё в eax старое значение.
inc64: то же самое с единицей в rax (`lock xadd qword ptr [rdi], rax`), а затем `inc rax`, чтобы вернуть новое значение.
