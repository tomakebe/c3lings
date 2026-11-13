После ucomisd SF/OF всегда 0, поэтому jl/jg бесполезны — нужны jb/ja/je.
Порядок проверок в fcompare: `jp` (NaN) → `je` (равны) → `jb` (меньше) → иначе больше. Добавьте метки для возврата 2 и 0.
clamp: `maxsd xmm0, xmm1` затем `minsd xmm0, xmm2`.
count_greater: сравнивайте `ucomisd xmm1, xmm0` (элемент с порогом) и пропускайте инкремент по `jbe` — он сработает и для NaN.
