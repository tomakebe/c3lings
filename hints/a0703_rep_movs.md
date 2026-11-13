memcpy: `mov rax, rdi` (вернуть dst) и `mov rcx, rdx` перед `rep movsb`.
memset: stosb пишет al, а сейчас там младший байт dst. Сохраните dst в r8,
положите c в eax (`mov eax, esi`), а в конце `mov rax, r8`.
fill32: `mov eax, esi` / `mov rcx, rdx` / `rep stosd`.
