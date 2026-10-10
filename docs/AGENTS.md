# AGENTS.md — «Орбитальный сад» / Orbital garden

## Проект

Roguelite deck-building + tower defense + cozy farm. Движок: **Godot 4.x, GDScript**,
текстовые сцены `.tscn` / ресурсы `.tres`. Платформы: Android, iOS, Steam Deck (Linux).
Ландшафт-онли, базовое разрешение 640×360, stretch `canvas\_items`, aspect `expand`.

## Контекстные документы (читать в начале каждой сессии)

* `docs/01\_Core\_Loop\_и\_правила\_карт.md` — core loop, ресурсы, пять правил карточки, закрытый список типов эффектов
* `docs/02\_Ростер\_карточек.md` — схема `CardResource`, 20 карт, стартовая колода, правила расширения ростера
* `docs/03\_План\_реализации.md` — фазы, порядок задач, операционные правила

## Текущая фаза

**Фаза 0 — выполнена**: структура проекта, настройки (640×360, canvas_items, expand, ландшафт),
главная сцена, git + первый коммит, headless-прогон и `tests/smoke_test.gd` зелёные.

**Фаза 1 — играбельный скелет (текущая)**:

* Задача 1 — Day/Night state machine: **выполнена** (`scripts/core/phase_machine.gd` + фазы, `EventBus`, `RunState`, `resources/run_config_default.tres`, тест `tests/phase_machine_test.gd` зелёный).
* Задача 2 — абстракция ввода: **выполнена** (`InputRouter`, action map в `project.godot`, сигналы `input_*` в `EventBus`, тест `tests/input_router_test.gd` зелёный).
* Задача 3 — сетка станции 4×4: **выполнена** (`GridLayout` + `resources/grid_layout_default.tres`, `GridManager`, `GridCursor`, `scenes/game/grid_view.tscn`, тест `tests/grid_test.gd` зелёный).
* Задача 4 — колода и рука: **выполнена** (`CardResource`/`EffectData`/`CardRegistry`, 6 стартовых карт .tres + реестр, `DeckManager`, `PlayController`, `CardEntity`, `HandView`, `DraftView`, тесты `card_contract_test.gd` и `deck_test.gd` зелёные).
* Задача 5 — ресурсы и экономика дня: **выполнена** (`EconomyManager`, `DayEffects` — утренний сбор generate/convert, оплата размещения/перемещения в `PlayController` (free_move у стены), ставка заката `SunsetView` с AFK-дефолтом РОСТ, `ResourcesBar`, тест `tests/economy_test.gd` зелёный).
* Задача 6 — wave manager: **выполнена** (`EnemyResource`/`SpawnEntry`/`WaveScenario`/`WaveSchedule`, враги .tres, 3 рукописные волны + расписание с клампом, `WaveManager` + `EnemyEntity`, тест `tests/wave_test.gd` зелёный).
* Задача 7 — auto-battle минимум (текущая).
* Далее по docs/03: HUD, сохранение.

## Команды

* Запуск проекта: `godot .`
* Headless-проверка: `godot --headless --quit`
* Тесты: `godot --headless -s res://tests/run\_tests.gd`
* Коммитим только когда headless-прогон зелёный.

## Жёсткие правила (нарушать нельзя)

1. **Одна система = один коммит = один headless-прогон.** Не смешивать системы в одной задаче.
2. **Числа баланса — в данных** (`resources/`), не в коде.
3. **Новая карта = новый `.tres` + запись в реестре.** Код не меняется.
4. Эффекты карт — **только из закрытого списка** (docs/01, раздел 7). Новый тип эффекта — отдельная задача с тестами, не часть карты.
5. **Ровно три ресурса**: энергия, вода, биомасса. Новые — только решением гейм-дизайнера (сначала обновить docs/01).
6. Прямые вызовы `Input.\*` в геймплейном коде **запрещены** — только через `InputRouter`, который переводит action map в сигналы `EventBus`. Полный список действий: `move\_cursor\_up/down/left/right`, `confirm`, `cancel`, `place\_card`, `active\_ability`. Тач и геймпад покрывают каждое действие.
7. `save\_version` с первого дня; сейвы игроков не ломаются никогда.
8. Тач и геймпад зеркалятся с первого дня.
9. Тесты обязательны на генератор волн и боевую математику.
10. Синергии — **данные** (таблица условий по тегам), не код.

## Плановая структура

```
scenes/      ui/ game/ entities/
scripts/     core/ systems/ data/
assets/      sprites/ audio/ fonts/
resources/   cards/ enemies/ waves/
tests/       docs/
```

## Нюансы headless-тестов (`-s` режим, Godot 4.7)

* Автозагрузы регистрируются **после** компиляции скрипта-раннера: прямой идентификатор `EventBus`/`RunState` в раннере не компилируется. Раннер берёт шину через `root.get_node("EventBus")`, а скрипты с `class\_name`-зависимостями грузит через `load()` в рантайме. В обычном запуске игры проблемы нет — это касается только тестов-раннеров.
* Лямбды GDScript захватывают локальные переменные **по значению**: сбор результатов из сигналов — только `append` в массив, не переприсваивание.
* Координаты кликов в событиях приходят в canvas-координатах (движок трансформирует из оконных из-за stretch `canvas\_items`): ожидаемую позицию в тесте считать через `root.get_screen_transform().affine_inverse() * window_pos`.
* Новый `class_name` требует пересканирования классов: `godot --headless --editor --quit`, иначе в `-s` тестах класс «не найден» (и раннер молча висит, т.к. падает до `quit()` — при зависшем тесте проверять это первым).
* Enum в GDScript 4 не callable: `Terrain(x)` не компилируется — приведение через таблицу значений.

## Стиль кода

* GDScript со статической типизацией, где возможно.
* Межсистемная коммуникация — сигналы/группы; автозагруз только для RunState, SaveSystem, EventBus.
* Данные — `class\_name` + `@export` ресурсы.
* Комментарии короткие, на русском.

## Дизайн-контракт

* Каждая карта: двойное назначение (дневная фаза подпитывает ночную), ≤2 ресурса, читается за 2 секунды.
* Редкости: common = простая функция, rare = +условие, epic = составное поведение.
* Стартовая колода: `turret\_laser`, `wall\_barrier`, `solar\_panel`, `moisture\_condenser`, `cactus\_battery`, `chicken\_incubator`.

