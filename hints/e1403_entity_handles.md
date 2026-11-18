Packing: `(gen << INDEX_BITS) | index`, unpacking: `h & INDEX_MASK` and `h >> INDEX_BITS`.
In `destroy`, `e.gen++;` is enough - the new generation won't match any handle handed out so far.
`resolve`: if `index >= self.used` - `return STALE_HANDLE~;`; then check `e.alive` and `e.gen == handle_gen(h)`.
