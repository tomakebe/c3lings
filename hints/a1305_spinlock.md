trylock: `mov eax, 1; xchg dword ptr [rdi], eax` — в eax старое значение (0 = было свободно). Верните его инверсию: `xor eax, 1`.
lock: попытка xchg; если не вышло — крутитесь `pause; cmp dword ptr [rdi], 0; jne` и затем снова к xchg.
unlock: одна обычная запись нуля — на x86 это уже release.
