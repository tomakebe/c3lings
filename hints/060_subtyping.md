Чтобы поля и методы Entity были доступны прямо на Player, а `&p` превращался в `Entity*`,
первый член надо объявить как `inline Entity base;`. То же для `Player player` в Boss.
Если все печатаются как "plain entity" — подтип совпадает с case родителя.
Переставьте case'ы: сначала самый конкретный (Boss), потом Player, потом Entity.
