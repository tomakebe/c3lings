`angle_between`: `d = math::abs(qdot(a, b))`, `if (d > 1.0f) d = 1.0f;`, `2.0f * math::acos(d)`.
`nlerp`: если `qdot(a, b) < 0` — `b = -b`; затем `qnormalize(a + (b - a) * t)`.
`slerp`: то же с `b` и с `d = -d`; при `d > 0.9995f` — `return nlerp(a, b, t)`;
иначе `w = acos(d)`, `s = sin(w)`, результат `a * (sin((1-t)*w)/s) + b * (sin(t*w)/s)`.
