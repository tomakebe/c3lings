`insert`: find the position pos - the first snapshot with time >= snap.time. Equal time - a duplicate, bail out.
If the buffer is full: if pos == 0 the snapshot is older than everything - bail out; otherwise shift everything left by one
(dropping s[0]) and decrement count and pos. Then open a gap in the array and insert at pos.
`sample`: empty or t < s[0].time - -1. t >= the time of the last one - take its x (0 if equal, 1 otherwise).
Otherwise find i with `s[i].time <= t < s[i+1].time` and interpolate using integers.
