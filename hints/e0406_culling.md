`plane_normalize`: `p / math::sqrt((p.xyz * p.xyz).sum())`. `plane_dist`: `(p.xyz * point).sum() + p.w`.
`extract_frustum`: `r0..r3 = row(vp, 0..3)`, затем по порядку
`left = r3 + r0, right = r3 - r0, bottom = r3 + r1, top = r3 - r1, near = r3 + r2, far = r3 - r2`,
каждую через `plane_normalize`.
Сфера невидима, если для КАКОЙ-ТО плоскости `plane_dist(p, c) < -r`; для AABB вместо `r`
берите `(math::abs(p.xyz) * e).sum()`.
