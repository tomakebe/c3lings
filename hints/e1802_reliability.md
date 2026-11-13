`seq_greater` — формула из шапки дословно.
`on_receive`: первый пакет — просто запомнить. Если `seq` новее `remote_ack`: shift = seq - remote_ack;
старые биты сдвигаются влево на shift, а старый ack становится битом (shift - 1); при shift > 32 биты обнуляются
(аккуратно: сдвиг uint на 32 и больше — ошибка). Если пакет старше: back = remote_ack - seq, при 1 <= back <= 32
установить бит (back - 1).
`process_acks`: `ack_one(ack)`, затем для каждого i из 0..31 с установленным битом — `ack_one(ack - (ushort)(i + 1))`.
