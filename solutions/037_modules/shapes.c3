// Подмодуль geometry::shapes. Тип Point из родительского модуля виден
// без префикса, а вот функции и константы родителя — только с префиксом.
module geometry::shapes;

struct Circle
{
    Point center;
    float radius;
}

fn float area(Circle c) => geometry::PI * c.radius * c.radius; // <- константа из модуля geometry

fn bool contains(Circle c, Point p)
{
    Point d = { p.x - c.center.x, p.y - c.center.y };
    return geometry::dot(d, d) <= c.radius * c.radius;
}
