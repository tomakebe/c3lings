`from_axis_angle`: `n = axis / sqrt(dot3(axis, axis))`, `s = sin(angle * 0.5f)`,
вернуть `{ n.x*s, n.y*s, n.z*s, cos(angle * 0.5f) }`.
`qmul`: векторная часть `b.xyz * a.w + a.xyz * b.w + cross(a.xyz, b.xyz)`,
скалярная `a.w*b.w - dot3(a.xyz, b.xyz)`. `conj`: минус у xyz.
`qnormalize`: `q / math::sqrt((q * q).sum())`.
`rotate`: `t = cross(q.xyz, p) * 2.0f; return p + t * q.w + cross(q.xyz, t);`
`to_mat4`: `x = rotate(q, {1,0,0})` и т.д.; столбцы `{ x.x, x.y, x.z, 0 }`, ..., `{ 0, 0, 0, 1 }`.
