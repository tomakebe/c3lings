trylock: `mov eax, 1; xchg dword ptr [rdi], eax` — eax holds the old value (0 = it was free). Return its inverse: `xor eax, 1`.
lock: try xchg; if it fails, spin with `pause; cmp dword ptr [rdi], 0; jne` and then go back to xchg.
unlock: a single plain store of zero — on x86 that is already release.
