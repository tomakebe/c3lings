push: `t = tail.load(RELAXED)`, `h = head.load(ACQUIRE)`; if `t - h == (uint)QCAP` - full, `false`.
Otherwise write `buf[t % QCAP] = c` and only THEN `tail.store(t + 1, RELEASE)`.
pop is the mirror image: your own `head` with RELAXED, the other side's `tail` with ACQUIRE, empty when `h == t`,
read the cell and THEN `head.store(h + 1, RELEASE)`.
The subtraction `t - h` on uint is correct even after the counters wrap around.
