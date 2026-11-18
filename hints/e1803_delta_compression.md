`encode_delta`: for each entity compare the three fields against the baseline. Nothing changed - `out.put(0, 1)`.
Otherwise `out.put(1, 1)`, then for each field: a "changed" bit and, if set, the value itself (16, 16, 7 bits).
`decode_delta` reads in exactly the same order: `out.e[i] = base.e[i];` then
`if (in.get(1) == 0) continue;` and three "bit + value" pairs.
