Set up four accumulator registers (min0, max0, min1, max1), all initialized to a[0], and start with i = 1.
Body: for a[i] — `cmp`/`cmovl` into min0 and `cmp`/`cmovg` into max0; for a[i+1] — the same into min1/max1; step by 2 while i < n - 1.
After the loop, merge the pairs with the same cmp/cmov and handle the last element if i == n - 1.
rcx (out_max) will hold the index — save the pointer in r11 beforehand. If you use rbx, save it with push/pop.
