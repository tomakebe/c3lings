Плавающие аргументы нумеруются отдельно от целых: первый double — xmm0, второй — xmm1 и т.д.
`subsd xmm0, xmm1` — это xmm0 = xmm0 - xmm1. Результат должен оказаться в xmm0.
lerp: всё во float, значит `subss`, `mulss`, `addss`.
mix_args: y — второй плавающий аргумент (xmm1) и он float; сначала `cvtss2sd xmm1, xmm1`, потом `addsd`.
