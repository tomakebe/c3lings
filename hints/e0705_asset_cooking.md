Little-endian u32: `for (int i = 0; i < 4; i++) out.push((char)(v >> (8 * i)));`. Для float: `put_u32(out, bitcast(v, uint));`.
Заголовок: `foreach (c : MAGIC) put_u8(out, c);` затем version, flags(0), vcount, icount, payload size, `fnv1a32(payload.array_view())`.
В load сравнение magic: `blob[:4] != MAGIC[..]` — срезы сравниваются поэлементно. Payload: `char[] payload = blob[HEADER_SIZE:size];`.
Индексы начинаются с `payload.ptr + vcount * 12` (3 float по 4 байта на вершину).
Помните: все проверки в load — до того, как вы поверите числам из заголовка.
