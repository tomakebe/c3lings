// The geometry::shapes submodule. The Point type from the parent module is visible
// without a prefix, but the parent's functions and constants only with a prefix.
module geometry::shapes;

struct Circle
{
    Point center;
    float radius;
}

fn float area(Circle c) => PI * c.radius * c.radius; // <- a constant from the geometry module

fn bool contains(Circle c, Point p)
{
    Point d = { p.x - c.center.x, p.y - c.center.y };
    return geometry::dot(d, d) <= c.radius * c.radius;
}
