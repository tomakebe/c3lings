Little-endian u32: `for (int i = 0; i < 4; i++) out.push((char)(v >> (8 * i)));`. For a float: `put_u32(out, bitcast(v, uint));`.
Header: `foreach (c : MAGIC) put_u8(out, c);` then version, flags(0), vcount, icount, payload size, `fnv1a32(payload.array_view())`.
In load, compare the magic with `blob[:4] != MAGIC[..]` — slices compare element-wise. Payload: `char[] payload = blob[HEADER_SIZE:size];`.
The indices start at `payload.ptr + vcount * 12` (3 floats of 4 bytes per vertex).
Remember: do all the checks in load before you trust the numbers in the header.
