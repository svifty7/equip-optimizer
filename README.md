# EquipOptimizer

[English Version](#english-description) | [Русская версия](#russian-description)

# English Description

EquipOptimizer is your ultimate in-game gear assistant for World of Warcraft. Stop wasting time exporting code to external simulators or manually mathing out stat weights on spreadsheets. Just tell the addon what stats you want to prioritize, and it will scan your bags to find and equip your best possible gear setup in seconds—completely lag-free!

## Addon Tabs

* Recommendations: View the recommended gear combination for all slots. You can see a detailed stats comparison (Current vs Recommended), and with a single click on Equip Best, the addon will sequentially and safely swap your gear.
* Gems: Suggests the best gems to insert into empty sockets on both your currently equipped and recommended gear to maximize your throughput according to your active stat rules.
* Caps: Performs soft-cap analysis. It tracks your stats against rules containing target caps (e.g., Haste 1240 rating), showing current rating vs the cap, and lists gear slots containing extra rating of those stats sorted by tuning priority so you know exactly which slots to swap out.
* Settings: The control center where you configure:
  * Stat Rules: Set your stat priorities and soft-caps (input values are flat stat ratings, not percentages. Primary stat and Item Level are tracked and prioritized automatically).
  * Set Requirements: Lock in your 2-piece or 4-piece Tier Set bonuses.
  * Reserved Slots: Check specific slots (like Legendaries or favorite trinkets) that you want the addon to ignore.
  * Profile Management: Save, load, and import/export profiles for different specs or scenarios.

## Addon Features

* No More Guesswork: Instantly see which items in your bags are actual upgrades when combined with your current gear.
* Play Your Way (Stat Rules): Easily set up your spec's priorities (e.g., "Get Haste to 1240 rating first, then stack as much Critical Strike as possible").
* Protect Your Tier Sets: Keep your 2-piece or 4-piece set bonuses active while the addon optimizes other slots.
* Perfect Gemming Made Easy: Tells you exactly which gems to slot based on your active stat priorities.
* Lock Your Favorites: Lock specific slots, and the addon will build the rest of your gear around them.
* Completely Lag-Free: Heavy gear permutation calculations run asynchronously using coroutines, keeping your FPS high and preventing game freezes.

## Gameplay Examples

### Scenario A: Reaching That Perfect Haste Cap
Your specialization feels great once you hit 1240 Haste rating, but stacking any more than that is a waste of stats.
* Without the Addon: You spend 10 minutes dragging rings and necklaces on and off, trying to get as close to 1240 rating as possible without going over.
* With EquipOptimizer: You set Haste target to 1240 as Rule 1, and Critical Strike as Rule 2. The addon scans your bags, hits exactly 1240 Haste, and fills every remaining stat budget with Crit.

### Scenario B: Upgrading Gear Without Breaking Set Bonuses
You just got a massive Item Level upgrade chest piece from a raid boss, but equipping it would break your 4-piece Tier Set bonus.
* Without the Addon: You might leave the new chest piece in your bags out of fear, or break your set bonus and lose a powerful passive effect.
* With EquipOptimizer: You tell the addon to maintain a 4-piece set. It automatically searches your bags for a different combination (like swapping a ring and gloves) that lets you wear the new chest piece and keep your set bonus active.

## How to Use

1. Open the Menu: Click the minimap icon or type /eo (or /equipopt) in chat.
2. Configure Settings:
   * Go to the Settings tab.
   * Under Stat Rules, add the stats you care about in order of preference (e.g., Haste, then Crit).
   * Under Set Requirements, specify if you must maintain a 2-piece or 4-piece tier bonus.
   * Under Reserved Slots, check the boxes for any gear slots you want the addon to ignore (like a legendary or favorite trinket).
3. Get Recommendations & Swap: Go to the Recommendations tab, and click Equip Best to swap your gear!
4. Optimize Sockets: Check the Gems tab to see the recommended gems for your sockets.
5. Refine Soft-Caps: Use the Caps tab to see which items have excessive ratings that can be swapped out to hit your caps more precisely.

# Russian Description

EquipOptimizer — это ваш личный помощник по подбору экипировки прямо в World of Warcraft. Забудьте о постоянном копировании кодов для внешних симуляторов и ручном подсчете характеристик в таблицах. Просто укажите аддону, какие характеристики вам нужны, и он за секунды найдет в ваших сумках и наденет лучшую комбинацию вещей — абсолютно без зависаний игры!

## Вкладки аддона

* Рекомендации (Recommendations): Показывает оптимальный набор экипировки для всех слотов. Вы можете увидеть детальное сравнение характеристик (Текущие против Рекомендованных), и в один клик по кнопке Надеть лучшее (Equip Best) аддон безопасно и поочередно переоденет персонажа.
* Самоцветы (Gems): Рекомендует лучшие камни для пустых гнезд как на текущей, так и на рекомендованной экипировке для максимизации пользы в соответствии с вашими правилами характеристик.
* Капы (Caps): Выполняет анализ софт-капов. Отслеживает характеристики, для которых заданы целевые значения (например, Скорость 1240 рейтинга), показывая текущий рейтинг относительно капа, а также выводит список слотов экипировки с избыточными характеристиками, отсортированный по приоритету настройки.
* Настройки (Settings): Главная панель управления, где вы можете настроить:
  * Правила характеристик (Stat Rules): Задавайте приоритеты характеристик и софт-капы (вводятся значения рейтинга, а не проценты. Основная характеристика и уровень предмета учитываются автоматически с наивысшим приоритетом).
  * Требования к комплектам (Set Requirements): Указывайте необходимость сохранения бонусов от 2 или 4 предметов комплекта.
  * Заблокированные слоты (Reserved Slots): Выбирайте слоты (например, легендарные предметы или аксессуары), которые аддон не должен изменять.
  * Управление профилями (Profiles): Сохраняйте, загружайте и импортируйте/экспортируйте профили для разных специализаций и ситуаций.

## Возможности аддона

* Больше никакого выбора наугад: Аддон мгновенно показывает, какие вещи в ваших сумках действительно усилят персонажа в сочетании с остальной экипировкой.
* Настройка под ваш стиль игры: Легко задавайте приоритеты (например: "Сначала соберите 1240 рейтинга скорости, а всё остальное вложите в критический удар").
* Сохранение бонусов комплектов (сетов): Сохраняйте бонусы от 2 или 4 кусков сета активными, пока аддон оптимизирует остальные слоты.
* Идеальный подбор самоцветов: Узнайте точные рекомендации по камням на основе ваших приоритетов характеристик.
* Блокировка любимых вещей: Заблокируйте нужный слот, и аддон подберет экипировку вокруг этой вещи.
* Играйте без лагов: Тяжелые вычисления перестановок экипировки выполняются асинхронно с помощью корутин, сохраняя высокий FPS и предотвращая зависания игры.

## Примеры использования

### Сценарий А: Сбор идеального капа Скорости
Вашему персонажу для идеальной ротации нужно 1240 рейтинга Скорости, а собирать больше — пустая трата характеристик.
* Без аддона: Вы тратите 10 минут, примеряя разные кольца и ожерелья, пытаясь подойти как можно ближе к 1240 рейтинга и не перебрать лишнего.
* С EquipOptimizer: Вы создаете правило с целью 1240 для скорости, а вторым правилом ставите «Критический удар». Аддон подбирает вещи так, чтобы получить ровно 1240 рейтинга скорости, а все остальные ресурсы экипировки направляет в Крит.

### Сценарий Б: Обновление экипировки без потери бонуса комплекта
Вы выбили отличный нагрудник высокого уровня в рейде, но если его надеть, то разрушится бонус от 4 предметов комплекта.
* Без аддона: Вы либо оставите новую вещь пылиться в сумке, либо наденете её, потеряв мощный сетовый эффект.
* С EquipOptimizer: Вы указываете требование сохранить 4 предмета комплекта. Аддон сам найдет другую комбинацию вещей в сумках (например, заменив кольцо и перчатки), которая позволит и новую вещь надеть, и сетовый бонус не потерять.

## Как использовать

1. Открыть меню: Нажмите на иконку у мини-карты или введите /eo (или /equipopt) в чате.
2. Настроить параметры:
   * Перейдите во вкладку Настройки (Settings).
   * В разделе Правила характеристик (Stat Rules) добавьте нужные статы в порядке важности (например: Скорость, затем Крит).
   * В разделе Комплекты (Set Requirements) выберите необходимость сохранять 2 или 4 предмета сета.
   * В разделе Заблокированные слоты (Reserved Slots) отметьте галочками слоты, которые аддон не должен менять (например, легендарку).
3. Получить рекомендации и переодеться: Перейдите во вкладку Рекомендации (Recommendations) и нажмите кнопку Надеть лучшее (Equip Best), чтобы мгновенно переодеть персонажа!
4. Подобрать камни: Загляните во вкладку Самоцветы (Gems), чтобы увидеть рекомендации по заполнению пустых гнезд.
5. Настроить софт-капы: Используйте вкладку Капы (Caps), чтобы увидеть, какие предметы имеют избыточный рейтинг и могут быть заменены для более точного достижения капов.
