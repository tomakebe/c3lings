LT: two pops, then the bytes `48 39 C8`, `0F 9C C0`, `0F B6 C0`, and a push.
JMP: `e.byte(0xE9)`, then record `{ e.len, ins.arg }` in fixups and write `e.u32(0)`. JZ is the same after `pop rax; test rax, rax` and `0F 84`.
CALL: the byte sequence is given in the header; the function address is `(long)(uptr)host_table[ins.arg]`.
Patches: for each fixup, `e.patch32(f.pos, (int)((long)label[f.target] - (long)(f.pos + 4)))`.
