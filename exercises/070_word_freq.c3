// =====================================================================
//  070 · Мини-проект: частотный словарь
// =====================================================================
//
//  Пора собрать вместе всё из второй части: строки, временную память,
//  HashMap, List, сортировку с компаратором, форматирование и
//  итераторы. Задача классическая — посчитать, какие слова чаще всего
//  встречаются в тексте.
//
//  План программы:
//
//    1. Разбить текст на слова. `text.tokenize("\n")` даёт Splitter —
//       итератор по строкам (068), а `line.tokenize(" ")` — по словам
//       строки. Осторожно: аргумент tokenize — это РАЗДЕЛИТЕЛЬ-подстрока,
//       а не набор символов: tokenize(" \n") искал бы пару «пробел+\n».
//
//    2. Нормализовать каждое слово: "Cat," "cat" и "CAT!" — одно и то же
//       слово "cat". Оставляем только буквы (и апостроф внутри: "don't"),
//       приводим к нижнему регистру. Строим результат в DString или
//       копируем-и-меняем; удобные кусочки stdlib:
//           c.is_alpha(), c.to_lower()        — методы char
//           s.to_lower_tcopy()                — копия строки в нижнем регистре
//           s.trim("...")                     — срез без указанных символов по краям
//       Слово может оказаться пустым (например, "—" или "123") —
//       такие пропускаем.
//
//    3. Посчитать: HashMap{String, int}. Помните: ключи-строки таблица
//       копирует сама, так что временные строки ключами класть можно.
//           counts[word] = (counts[word] ?? 0) + 1;
//
//    4. Отсортировать: переложить пары в List{WordCount} (или срез) и
//       отсортировать компаратором: сначала по убыванию частоты, при
//       равной частоте — по алфавиту. Второй ключ делает вывод
//       детерминированным: порядок обхода HashMap не определён.
//
//    5. Напечатать топ-N в аккуратной таблице (`%-8s`, `%2d`).
//
//  Память: всё временное — внутри `@pool`; HashMap и List в куче
//  освобождаются через `defer`. Программа обёрнута в `@assert_leak`,
//  так что утечка не пройдёт незамеченной.
//
//  ЗАДАЧА: реализуйте три функции, помеченные TODO:
//    * normalize — нормализация одного слова (во временной памяти);
//    * count_words — подсчёт слов текста в таблицу;
//    * by_frequency — компаратор для сортировки.
//  Остальное уже написано. Ожидаемый вывод:
//      words: 44, unique: 27
//      the      7 #######
//      and      3 ###
//      cat      3 ###
//      it       3 ###
//      a        2 ##
//      bird     2 ##
//
import std::io;
import std::sort;
import std::collections::map;
import std::collections::list;

const String TEXT = `The cat sat on the mat. The dog sat on the log,
and THE cat saw the dog! "A cat?" said a bird. Cat's eyes are bright,
and the bird flew away -- it didn't like it, and nobody blamed it.
Dogs bark; cats nap.`;

struct WordCount
{
    String word;
    int count;
}

// Нормализует слово: только буквы и апостроф, нижний регистр.
// "THE" -> "the", "dog!" -> "dog", "\"A" -> "a", "didn't" -> "didn't", "--" -> "".
// Результат — во временной памяти.
fn String normalize(String raw)
{
    // TODO
    return raw;
}

// Разбивает текст на слова, нормализует их и считает в `counts`.
// Возвращает общее количество (непустых) слов.
fn int count_words(String text, HashMap{String, int}* counts)
{
    // TODO
    return 0;
}

// По убыванию count; при равенстве — по алфавиту.
fn int by_frequency(WordCount* a, WordCount* b)
{
    // TODO
    return 0;
}

fn void main()
{
    @assert_leak()
    {
        HashMap{String, int} counts;
        counts.init(mem);
        defer counts.free();

        int total;
        @pool()
        {
            total = count_words(TEXT, &counts);
        };
        io::printfn("words: %d, unique: %d", total, counts.len());

        List{WordCount} entries;
        entries.init(mem);
        defer entries.free();
        // @each — макрос-итератор HashMap: тело вызывается для каждой пары.
        // Строки word принадлежат таблице и живут, пока жива counts.
        counts.@each(; String word, int count)
        {
            entries.push({ word, count });
        };
        quicksort(&entries, &by_frequency);

        for (sz i = 0; i < 6 && i < entries.len(); i++)
        {
            WordCount e = entries[i];
            @pool()
            {
                DString bar;
                bar.append_repeat('#', e.count);
                io::printfn("%-8s%2d %s", e.word, e.count, bar);
            };
        }
    };
}
