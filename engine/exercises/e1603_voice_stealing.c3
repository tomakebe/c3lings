// =====================================================================
//  e1603 · Голосовой менеджер и кража голосов (voice stealing)
// =====================================================================
//
//  Микшировать бесконечно много звуков нельзя: каждый голос стоит
//  CPU (декодирование, ресэмплинг, фильтры, 3D). Поэтому у движка есть
//  фиксированный пул «реальных» голосов (32–128 на консолях), а запросов
//  «сыграй звук» в кадр боя может быть сотни.
//
//  Когда свободных голосов нет, менеджер решает, кого «украсть»:
//
//      1. жертва — голос с НАИМЕНЬШИМ приоритетом;
//      2. при равенстве — самый ТИХИЙ (его потерю никто не услышит);
//      3. при равенстве — самый СТАРЫЙ (он уже почти доиграл).
//
//  Если даже у жертвы приоритет ВЫШЕ, чем у нового звука, — новый звук
//  отклоняется (выстрел героя не должен вытеснять музыку, а шаги NPC —
//  выстрел героя). При равном приоритете новый звук побеждает.
//
//  Игровой код держит не указатель на голос, а ХЕНДЛ {index, generation}
//  (см. главу 03). Когда голос крадут, его поколение растёт — и старый
//  хендл перестаёт работать: stop() по нему ничего не сделает, а
//  is_playing() вернёт false. Без этого игра остановила бы ЧУЖОЙ звук,
//  занявший тот же слот, — классический баг.
//
//  (В FMOD/Wwise есть ещё «виртуальные голоса»: украденный звук
//  продолжает «идти» без микширования и может вернуться, когда
//  освободится место. Здесь мы его просто останавливаем.)
//
//  ЗАДАЧА: реализуйте VoiceManager.play, is_playing и stop.
//
import std::io;

const int MAX_VOICES = 4;
const ushort INVALID_INDEX = 0xFFFF;

struct VoiceHandle
{
    ushort index;
    ushort gen;
}

struct Voice
{
    int sound;
    int priority;
    float volume;
    uint start_tick;   // когда голос начал играть
    ushort gen;
    bool active;
}

struct VoiceManager
{
    Voice[MAX_VOICES] voices;
    uint tick;
    int stolen;
    int rejected;
}

fn bool VoiceHandle.valid(self) => self.index != INVALID_INDEX;

// Запустить звук. Возвращает хендл или {INVALID_INDEX, 0}, если отклонён.
fn VoiceHandle VoiceManager.play(&self, int sound, int priority, float volume)
{
    self.tick++;
    // TODO: найти свободный голос; если нет — выбрать жертву по правилам
    // из шапки или отклонить. Не забудьте увеличить поколение слота.
    return { INVALID_INDEX, 0 };
}

fn bool VoiceManager.is_playing(&self, VoiceHandle h)
{
    return h.valid(); // TODO: проверить поколение
}

fn void VoiceManager.stop(&self, VoiceHandle h)
{
    // TODO: остановить, только если хендл всё ещё «живой»
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

fn void VoiceManager.dump(&self)
{
    for (int i = 0; i < MAX_VOICES; i++)
    {
        Voice* v = &self.voices[i];
        if (v.active)
        {
            io::printfn("  slot %d: sound=%d prio=%d vol=%d%% tick=%d", i, v.sound, v.priority, (int)(v.volume * 100 + 0.5f), v.start_tick);
        }
        else
        {
            io::printfn("  slot %d: free", i);
        }
    }
}

const int MUSIC = 100;
const int GUNSHOT = 1;
const int FOOTSTEP = 2;
const int EXPLOSION = 3;

fn void main()
{
    VoiceManager vm;
    VoiceHandle music = vm.play(MUSIC, 10, 0.7f);
    VoiceHandle step1 = vm.play(FOOTSTEP, 1, 0.3f);
    VoiceHandle step2 = vm.play(FOOTSTEP, 1, 0.2f);
    VoiceHandle shot1 = vm.play(GUNSHOT, 5, 0.9f);
    assert(music.valid() && step1.valid() && step2.valid() && shot1.valid());
    assert(vm.stolen == 0);

    // пул полон: шаг с низким приоритетом крадёт самый тихий шаг (step2)
    VoiceHandle step3 = vm.play(FOOTSTEP, 1, 0.25f);
    assert(step3.valid() && step3.index == step2.index, "жертва — самый тихий из низкоприоритетных");
    assert(!vm.is_playing(step2), "украденный хендл должен умереть");
    assert(vm.is_playing(step3));

    // ещё шаг с той же громкостью 0.25: самый тихий теперь step3 (0.25 < 0.3)
    VoiceHandle step4 = vm.play(FOOTSTEP, 1, 0.25f);
    assert(step4.index == step3.index);

    // два выстрела: первый крадёт step4 (prio 1, тише), второй — step1
    VoiceHandle shot2 = vm.play(GUNSHOT, 5, 0.9f);
    VoiceHandle shot3 = vm.play(GUNSHOT, 5, 0.9f);
    assert(shot2.index == step4.index && shot3.index == step1.index);

    // все приоритеты >= 5: шаг (prio 1) отклоняется
    VoiceHandle step5 = vm.play(FOOTSTEP, 1, 1.0f);
    assert(!step5.valid() && vm.rejected == 1);

    // взрыв prio 5 при равенстве всего крадёт САМЫЙ СТАРЫЙ выстрел (shot1)
    VoiceHandle boom = vm.play(EXPLOSION, 5, 0.9f);
    assert(boom.index == shot1.index, "при равных prio и громкости — самый старый");

    // старые хендлы безопасны
    vm.stop(shot1);          // ничего не делает: слот занят взрывом
    assert(vm.is_playing(boom));
    vm.stop(boom);
    assert(!vm.is_playing(boom));
    vm.stop(boom);           // повторный stop — тоже безопасен
    assert(vm.is_playing(music), "музыку никто не тронул");

    io::printfn("stolen=%d rejected=%d", vm.stolen, vm.rejected);
    vm.dump();
}
