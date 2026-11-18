After ucomisd SF/OF are always 0, so jl/jg are useless — you need jb/ja/je.
Order of checks in fcompare: `jp` (NaN) → `je` (equal) → `jb` (less) → otherwise greater. Add labels for returning 2 and 0.
clamp: `maxsd xmm0, xmm1` then `minsd xmm0, xmm2`.
count_greater: compare with `ucomisd xmm1, xmm0` (element against threshold) and skip the increment with `jbe` — it also fires for NaN.
