Вариант с rbx: в начале .Lrecurse сделайте `push rbx` / `mov rbx, rdi`;
после call — `imul rax, rbx` / `pop rbx` / `ret`.
Почему исходная версия считает неправильно: вложенный вызов asm_fact тоже
пишет в rcx, и после возврата там уже не наше n.
