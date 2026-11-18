Alignment: `while ((usz)out.len() % ALIGN != 0) out.push(0);` (List.len() returns a signed `sz`).
Sorting: `sort::quicksort(entries, fn int(TocEntry a, TocEntry b) => a.id < b.id ? -1 : (a.id > b.id ? 1 : 0));`.
Binary search over a half-open interval: `usz lo = 0, hi = self.count; while (lo < hi) { usz mid = lo + (hi - lo) / 2; ... }`, and remember that `if/else` in C3 always needs braces.
TOC entry number mid starts at `self.toc + mid * TOC_ENTRY_SIZE`.
In acquire: `char[]? data = pak.find(id); if (catch data) continue;` — after that `data` is unwrapped.
