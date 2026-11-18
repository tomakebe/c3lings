1. A method name starts with the type name: `fn int Vec2.length_sq(self)`.
2. With `self` the method works on a copy. To change the object itself you need `&self`.
3. A method is called with a dot: `v.scale(2);`.
