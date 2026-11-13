`apply`: `self.pos + rotate(self.rot, p * self.scale)`.
`compose` возвращает `{ pos, rot, scale }` по формулам шапки: обратите внимание, что позиция
ребёнка сначала масштабируется и поворачивается РОДИТЕЛЕМ.
`to_mat4`: `x = rotate(rot, { scale, 0, 0 })` и т.д., четвёртый столбец `{ pos.x, pos.y, pos.z, 1 }`.
`aabb_transform`: `c = (min+max)/2`, `e = (max-min)/2`; новый центр `mul_vec(m, {c,1}).xyz`;
новые полуразмеры `math::abs(m.cols[0].xyz) * e.x + math::abs(m.cols[1].xyz) * e.y + ... * e.z`.
