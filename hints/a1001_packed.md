`addss` — scalar single (один элемент), `addps` — packed single (все четыре).
Размножение скаляра: `shufps xmm0, xmm0, 0` — все четыре поля берут элемент 0.
add_arrays: индекс в rax, адреса `[rsi + rax*4]`, загружайте `movups` (не `movaps` — адреса не выровнены, и не `addps xmm0, [mem]` — это тоже требует выравнивания), шаг 4.
