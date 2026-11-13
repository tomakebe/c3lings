`init`: `bs = align_up(item_size, align)`, и если `bs < FreeNode::size` — `bs = align_up(FreeNode::size, align)`.
`capacity = buf.len / bs`. Список удобно строить С КОНЦА: для i от capacity-1 до 0
`node = (FreeNode*)(base + i*bs); node.next = free_head; free_head = node;` (осторожно с
беззнаковым циклом вниз: `for (usz i = cap; i > 0; i--)` и блок `i - 1`).
`alloc`: снять голову. `free`: `off = (usz)p - (usz)base`; отвергнуть `p < base`,
`off >= capacity*bs` и `off % bs != 0`; затем положить блок в голову.
