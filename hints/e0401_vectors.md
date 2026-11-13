`dot`: `(a * b).sum()`. `cross`: формула из шапки со swizzle `.yzx` и `.zxy`.
`length`: `math::sqrt(dot(v, v))`. `normalize`: если длина `< 1e-8f` — вернуть `{ 0, 0, 0 }`,
иначе `v / len`. `lerp`: `a + (b - a) * t`.
`approx_eq`: `Vec3 d = math::abs(a - b);` и проверка `d.x <= eps && d.y <= eps && d.z <= eps`.
`reflect`: `v - n * (2.0f * dot(v, n))`.
