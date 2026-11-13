find: в цикле `cmp dword ptr [rdi + ITEM_KEY], esi` / `je` найдено (вернуть rdi), иначе p = p->next.
sum: `add rax, [rdi + ITEM_PAYLOAD]` в цикле обхода.
reverse: rax = prev = 0, rdi = cur. Цикл: `mov rcx, [rdi + ITEM_NEXT]` (next);
`mov [rdi + ITEM_NEXT], rax`; `mov rax, rdi`; `mov rdi, rcx`. Ответ уже в rax.
