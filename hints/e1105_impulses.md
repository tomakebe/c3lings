Скалярное «векторное произведение» в 2D — `cross(a, b)`, а `w × r` — `cross_sv(w, r)`; обе функции уже есть.
`K = a.inv_mass + b.inv_mass + ran*ran*a.inv_inertia + rbn*rbn*b.inv_inertia`, где `ran = cross(ra, n)`.
Трение считайте ПОСЛЕ нормального импульса — по новой относительной скорости; конус: `math::clamp(jt, -mu*j, mu*j)`.
Скорость точки диска: `v + cross_sv(w, r)`. Коррекция: `a.pos -= n * (corr * a.inv_mass); b.pos += n * (corr * b.inv_mass);`.
