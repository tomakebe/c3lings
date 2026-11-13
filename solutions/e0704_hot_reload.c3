// =====================================================================
//  e0704 · Hot reload по времени изменения файлов
// =====================================================================
//
//  Сначала прочитайте engine/docs/07_resources.md (раздел «Hot reload»).
//
//  Художник сохраняет текстуру в Photoshop — и через полсекунды она уже
//  в запущенной игре. Это экономит часы в день, и любой серьёзный движок
//  это умеет. Самый простой и переносимый способ узнать об изменении —
//  периодически (раз в N кадров) опрашивать время модификации файлов:
//
//      std::io::file::last_modified(path)   -> Time?  (ошибка, если файла нет)
//
//  Подписка на события ОС (inotify, ReadDirectoryChangesW, FSEvents)
//  точнее и дешевле, но три разных API; опрос mtime работает везде.
//
//  Хорошая система hot reload соблюдает три правила:
//
//  1. Транзакционность. Файл могут сохранить «наполовину» или с ошибкой.
//     Сначала разбираем новые данные во временную структуру и только при
//     успехе подменяем старые. При ошибке — сообщение в лог и работа со
//     СТАРОЙ версией. Игра не должна падать от опечатки в материале.
//  2. Зависимости. Материал ссылается на шейдер. Перезагрузили шейдер —
//     надо заново «слинковать» все материалы, которые на него ссылаются,
//     хотя их файлы не менялись.
//  3. Исчезновение файла (переименовали, git checkout в процессе) — это
//     не повод выгружать ресурс. Предупреждаем ОДИН раз и ждём, пока файл
//     вернётся (с новым mtime).
//
//  В этом упражнении файлы настоящие — они пишутся в текущий каталог.
//  Чтобы тест был детерминированным, mtime выставляется явно через
//  file::set_modified_time (иначе два сохранения в одну секунду имели бы
//  одинаковое время — это, кстати, реальная проблема опроса mtime).
//
//  ЗАДАЧА: реализуйте Watcher.poll() (TODO ниже). Для каждого ресурса:
//    * last_modified не удалось -> если ещё не missing: missing = true,
//      лог "  WARN <path>: missing, keeping v<N>"; дальше не обрабатывать;
//    * файл есть: missing = false; если mtime не изменился — пропустить;
//    * иначе запомнить новый mtime (даже если разбор провалится — иначе
//      мы будем пытаться перечитать битый файл каждый опрос) и вызвать
//      self.reload(i): при ошибке лог "  ERROR <path>: keeping v<N>",
//      при успехе — version++, лог "  reload <path> v<N>", reloads++.
//    * после прохода по всем файлам — перелинковать (self.link(i)) все
//      материалы, которые были перезагружены сами или чей шейдер был
//      перезагружен в этом опросе.
//  poll возвращает число успешных перезагрузок.
//
import std::io, std::time, libc;

excuse PARSE_ERROR;

enum Kind : char { SHADER, MATERIAL }

struct Entry
{
    String path;
    Kind kind;
    Time mtime;
    int version;
    bool missing;
    // SHADER
    int brightness;
    // MATERIAL
    int shader;          // индекс шейдера в Watcher.entries
    int[3] color;
    int[3] final_color;  // результат линковки: color * brightness
}

const int MAX_ENTRIES = 4;

struct Watcher
{
    Entry[MAX_ENTRIES] entries;
    int count;
}

// ---------------------------------------------------------------------
// Разбор (дан готовым). Пишет в *out только при полном успехе.
// Шейдер:   "brightness <int>"
// Материал: "shader <path>\ncolor <r> <g> <b>"
// ---------------------------------------------------------------------
fn void? Watcher.parse(&self, int i, String text, Entry* out) => @pool()
{
    Entry tmp = self.entries[i];
    bool has_a, has_b;
    foreach (raw : text.tsplit("\n"))
    {
        String line = raw.trim();
        if (line.len == 0) continue;
        String[] w = line.tsplit(" ");
        if (tmp.kind == SHADER && w[0] == "brightness" && w.len == 2)
        {
            tmp.brightness = w[1].to_int()!;
            has_a = has_b = true;
        }
        else if (tmp.kind == MATERIAL && w[0] == "shader" && w.len == 2)
        {
            int s = self.find(w[1]);
            if (s < 0) return PARSE_ERROR~;
            tmp.shader = s;
            has_a = true;
        }
        else if (tmp.kind == MATERIAL && w[0] == "color" && w.len == 4)
        {
            for (int c = 0; c < 3; c++) tmp.color[c] = w[c + 1].to_int()!;
            has_b = true;
        }
        else
        {
            return PARSE_ERROR~;
        }
    }
    if (!has_a || !has_b) return PARSE_ERROR~;
    *out = tmp;
}

fn int Watcher.find(&self, String path)
{
    for (int i = 0; i < self.count; i++) if (self.entries[i].path == path) return i;
    return -1;
}

// Читает файл и, если он корректен, подменяет данные ресурса.
fn void? Watcher.reload(&self, int i) => @pool()
{
    char[] text = file::load_temp(self.entries[i].path)!;
    Entry fresh;
    self.parse(i, (String)text, &fresh)!;
    self.entries[i] = fresh;
}

fn void Watcher.link(&self, int i)
{
    Entry* m = &self.entries[i];
    int b = self.entries[m.shader].brightness;
    for (int c = 0; c < 3; c++) m.final_color[c] = m.color[c] * b;
    io::printfn("  relink %s -> color %d %d %d", m.path,
                m.final_color[0], m.final_color[1], m.final_color[2]);
}

fn void Watcher.add(&self, String path, Kind kind)
{
    int i = self.count++;
    self.entries[i] = { .path = path, .kind = kind };
    self.entries[i].mtime = file::last_modified(path)!!;
    self.reload(i)!!;
    self.entries[i].version = 1;
    if (kind == MATERIAL) self.link(i);
}

fn int Watcher.poll(&self)
{
    int reloads = 0;
    bool[MAX_ENTRIES] changed;
    for (int i = 0; i < self.count; i++)
    {
        Entry* e = &self.entries[i];
        Time? t = file::last_modified(e.path);
        if (catch t)
        {
            if (!e.missing)
            {
                e.missing = true;
                io::printfn("  WARN %s: missing, keeping v%d", e.path, e.version);
            }
            continue;
        }
        e.missing = false;
        if (t == e.mtime) continue;
        e.mtime = t;
        if (catch self.reload(i))
        {
            io::printfn("  ERROR %s: keeping v%d", e.path, e.version);
            continue;
        }
        e.version++;
        changed[i] = true;
        reloads++;
        io::printfn("  reload %s v%d", e.path, e.version);
    }
    for (int i = 0; i < self.count; i++)
    {
        Entry* e = &self.entries[i];
        if (e.kind == MATERIAL && (changed[i] || changed[e.shader])) self.link(i);
    }
    return reloads;
}

// ---------------------------------------------------------------------
// Тест: «художник» правит файлы, игра опрашивает.
// ---------------------------------------------------------------------
const String SHADER_FILE = "e0704_base.shader";
const String HERO_FILE = "e0704_hero.mat";
const String ROCK_FILE = "e0704_rock.mat";

fn void edit(String path, String text, long mtime)
{
    file::save(path, text)!!;
    file::set_modified_time(path, (Time_t)mtime)!!;
}

fn void main()
{
    edit(SHADER_FILE, "brightness 2\n", 1000);
    edit(HERO_FILE, "shader e0704_base.shader\ncolor 10 20 30\n", 1000);
    edit(ROCK_FILE, "shader e0704_base.shader\ncolor 1 1 1\n", 1000);

    Watcher w;
    io::printn("startup:");
    w.add(SHADER_FILE, SHADER);
    w.add(HERO_FILE, MATERIAL);
    w.add(ROCK_FILE, MATERIAL);
    Entry* hero = &w.entries[1];
    Entry* rock = &w.entries[2];

    io::printn("poll 1 (nothing changed):");
    assert(w.poll() == 0, "unchanged files must not be reloaded");

    io::printn("poll 2 (shader edited):");
    edit(SHADER_FILE, "brightness 3\n", 2000);
    assert(w.poll() == 1);
    assert(w.entries[0].version == 2 && w.entries[0].brightness == 3);
    assert(hero.version == 1, "hero.mat itself did not change");
    assert(hero.final_color[2] == 90 && rock.final_color[0] == 3,
           "materials depending on the shader must be relinked");

    io::printn("poll 3 (hero.mat saved with a typo):");
    edit(HERO_FILE, "shader e0704_base.shader\ncolour 50 50 50\n", 3000);
    assert(w.poll() == 0);
    assert(hero.version == 1 && hero.color[0] == 10, "a broken file must not replace good data");
    assert(hero.mtime == (Time)(3000 * (long)time::SEC), "mtime must be remembered even if the parse failed");

    io::printn("poll 4 (nothing changed - broken file is not re-read):");
    assert(w.poll() == 0);

    io::printn("poll 5 (typo fixed, rock.mat edited too):");
    edit(HERO_FILE, "shader e0704_base.shader\ncolor 50 50 50\n", 4000);
    edit(ROCK_FILE, "shader e0704_base.shader\ncolor 7 7 7\n", 4000);
    assert(w.poll() == 2);
    assert(hero.version == 2 && hero.final_color[0] == 150);
    assert(rock.version == 2 && rock.final_color[1] == 21);

    io::printn("poll 6,7 (shader deleted):");
    file::delete(SHADER_FILE);
    assert(w.poll() == 0);
    assert(w.entries[0].missing && w.entries[0].brightness == 3, "keep the old data when the file is gone");
    assert(w.poll() == 0);   // предупреждение только один раз

    io::printn("poll 8 (shader restored):");
    edit(SHADER_FILE, "brightness 1\n", 5000);
    assert(w.poll() == 1);
    assert(!w.entries[0].missing && w.entries[0].version == 3);
    assert(hero.final_color[0] == 50);

    file::delete(SHADER_FILE);
    file::delete(HERO_FILE);
    file::delete(ROCK_FILE);
    io::printn("hot reload works");
}
