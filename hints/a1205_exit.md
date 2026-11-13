Аргументы приходят как (msg = rdi, len = rsi), а write ждёт (fd = rdi, buf = rsi, len = rdx): переложите их в правильном порядке (сначала rdx = rsi, потом rsi = rdi).
Затем `xor edi, edi; mov eax, 231; syscall` и, для надёжности, `ud2`.
