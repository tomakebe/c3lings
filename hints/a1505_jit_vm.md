LT: два pop, затем байты `48 39 C8`, `0F 9C C0`, `0F B6 C0` и push.
JMP: `e.byte(0xE9)`, затем запомните `{ e.len, ins.arg }` в fixups и запишите `e.u32(0)`. JZ — то же после `pop rax; test rax, rax` и `0F 84`.
CALL: последовательность байтов дана в шапке; адрес функции — `(long)(uptr)host_table[ins.arg]`.
Заплатки: для каждого fixup `e.patch32(f.pos, (int)((long)label[f.target] - (long)(f.pos + 4)))`.
