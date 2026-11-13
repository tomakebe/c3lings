Сейчас `uint magic + uint version + uint flags` = 12 байт, а нужно 8: version и flags — `ushort`.
Условие «у x есть метод area» — `$defined(x.area())`.
