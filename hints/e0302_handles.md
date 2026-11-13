Упаковка: `(gen << INDEX_BITS) | (index & INDEX_MASK)`, распаковка — маска и сдвиг вправо.
`Handle` — typedef, поэтому для битовых операций кастуйте `(uint)h`, а результат — `(Handle)`.
`create`: из очереди берите `queue[q_head]`, затем `q_head = (q_head + 1) % CAP; q_len--`.
Новый слот: `i = next_unused++; gen[i] = 1;`. Не забудьте `alive[i] = true; live++`.
`destroy`: `alive = false; live--; gen[i]++`; если `gen[i] == GEN_LIMIT` — `retired++`
и выйти; иначе положить в хвост: `queue[(q_head + q_len) % CAP] = i; q_len++`.
