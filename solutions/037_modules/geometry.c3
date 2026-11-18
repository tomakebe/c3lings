// The geometry module: basic types and functions.
module geometry;

const float PI = 3.14159;

struct Point
{
    float x;
    float y;
}

fn float dot(Point a, Point b) => a.x * b.x + a.y * b.y;

fn float Point.len_sq(self) => dot(self, self);
