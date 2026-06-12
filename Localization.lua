-- Localization.lua for EquipOptimizer
local addonName, addonTable = ...
local L = {}
addonTable.L = L

local locale = GetLocale()

-- Default English translations
local enUS = {
    ADDON_TITLE = "EquipOptimizer",
    SETTINGS = "Settings",
    EQUIP_BEST = "Equip Best",
    IN_COMBAT = "In Combat",
    RULES = "Stat Rules & Targets",
    RULE_ADD = "Add Rule",
    RULE_REMOVE = "Remove",
    RULE_UP = "Up",
    RULE_DOWN = "Down",
    SLOT_LOCKS = "Reserved Slots (Ignore)",
    RECOMMENDATIONS = "Recommendations",
    PRIMARY_STATS = "Primary Stats",
    SECONDARY_STATS = "Secondary Stats",
    CURRENTLY_EQUIPPED = "Currently Equipped",
    RECOMMENDED = "Recommended",
    DIFF = "Difference",
    NO_RECS = "All slots are optimized or reserved!",
    NO_RULES = "No rules defined. Add rules to begin optimization.",
    MAXIMIZE = "Maximize",
    VALUE = "Value",
    STAT = "Stat",
    OPERATOR = "Op",
    PRIORITY = "Priority",
    PROFILE_MANAGEMENT = "Profile Management",
    ACTIVE_PROFILE = "Active Profile",
    NEW_PROFILE_NAME = "New Profile Name",
    DELETE = "Delete",
    IMPORT = "Import",
    EXPORT = "Export",
    IMPORT_EXPORT_STRING = "Import/Export String",
    RENAME_PROFILE = "Rename Profile",
    MINIMAP_TOOLTIP_LEFT = "Left Click: Open settings",
    MINIMAP_TOOLTIP_RIGHT = "Right Click: Equip best gear",
    EMPTY = "Empty",
    HELP_TOOLTIP_TITLE = "How to configure stats:",
    HELP_TOOLTIP_MIN = "• Minimum (%): The addon will pick items until it reaches the specified percentage. Perfect for important 'soft-caps' (e.g. 30% haste).",
    HELP_TOOLTIP_MAX = "• Maximize: The addon will equip items with this stat, ignoring the rest. Use for the strongest stat after caps are met.",
    HELP_TOOLTIP_ORDER = "• Order matters! Rules higher in the list are executed first.",

    
    -- Stats
    STAT_GROUP_SECONDARY = "Secondary Stats",
    STAT_GROUP_TERTIARY = "Tertiary Stats",
    STAT_CRIT = "Critical Strike (%)",
    STAT_HASTE = "Haste (%)",
    STAT_MASTERY = "Mastery (%)",
    STAT_VERSATILITY = "Versatility (%)",
    STAT_LEECH = "Leech (%)",
    STAT_AVOIDANCE = "Avoidance (%)",
    STAT_SPEED = "Speed (%)",
    STAT_INTELLECT = "Intellect",
    STAT_AGILITY = "Agility",
    STAT_STRENGTH = "Strength",
    STAT_STAMINA = "Stamina",
    STAT_ILVL = "Item Level",
    STAT_ARMOR = "Armor",

    -- Slots
    Slot_HEAD = "Head",
    Slot_NECK = "Neck",
    Slot_SHOULDER = "Shoulder",
    Slot_BACK = "Back",
    Slot_CHEST = "Chest",
    Slot_WRIST = "Wrist",
    Slot_HANDS = "Hands",
    Slot_WAIST = "Waist",
    Slot_LEGS = "Legs",
    Slot_FEET = "Feet",
    Slot_FINGER1 = "Ring 1",
    Slot_FINGER2 = "Ring 2",
    Slot_TRINKET1 = "Trinket 1",
    Slot_TRINKET2 = "Trinket 2",
    Slot_MAINHAND = "Main Hand",
    Slot_OFFHAND = "Off Hand",
}

-- Russian translations
local ruRU = {
    ADDON_TITLE = "EquipOptimizer",
    SETTINGS = "Настройки",
    EQUIP_BEST = "Надеть лучшее",
    IN_COMBAT = "Идет бой",
    RULES = "Правила и цели характеристик",
    RULE_ADD = "Добавить правило",
    RULE_REMOVE = "Удалить",
    RULE_UP = "Вверх",
    RULE_DOWN = "Вниз",
    SLOT_LOCKS = "Бронирование слотов (Игнорировать)",
    RECOMMENDATIONS = "Рекомендации",
    PRIMARY_STATS = "Основные характеристики",
    SECONDARY_STATS = "Второстепенные характеристики",
    CURRENTLY_EQUIPPED = "Экипировано",
    RECOMMENDED = "Рекомендуется",
    DIFF = "Разница",
    NO_RECS = "Все слоты оптимизированы или забронированы!",
    NO_RULES = "Правила не заданы. Добавьте правила, чтобы начать оптимизацию.",
    MAXIMIZE = "Максимизировать",
    VALUE = "Значение",
    STAT = "Характеристика",
    OPERATOR = "Усл.",
    PRIORITY = "Приоритет",
    PROFILE_MANAGEMENT = "Управление профилями",
    ACTIVE_PROFILE = "Активный профиль",
    NEW_PROFILE_NAME = "Новый профиль",
    DELETE = "Удалить",
    IMPORT = "Импорт",
    EXPORT = "Экспорт",
    IMPORT_EXPORT_STRING = "Строка импорта/экспорта",
    RENAME_PROFILE = "Переименовать",
    MINIMAP_TOOLTIP_LEFT = "ЛКМ: Открыть настройки",
    MINIMAP_TOOLTIP_RIGHT = "ПКМ: Надеть лучшее снаряжение",
    EMPTY = "Пусто",
    HELP_TOOLTIP_TITLE = "Как настраивать характеристики:",
    HELP_TOOLTIP_MIN = "• Минимум (%): Аддон будет подбирать вещи, пока не достигнет указанного процента. Идеально для сбора важных 'софт-капов' (например, 30% скорости).",
    HELP_TOOLTIP_MAX = "• Максимизировать: Аддон будет надевать вещи с этой характеристикой, игнорируя остальные. Используйте для самого сильного стата после того, как собраны капы.",
    HELP_TOOLTIP_ORDER = "• Порядок важен! Правила, стоящие ВЫШЕ в списке, выполняются первыми.",


    -- Stats
    STAT_GROUP_SECONDARY = "Вторичные характеристики",
    STAT_GROUP_TERTIARY = "Второстепенные характеристики",
    STAT_CRIT = "Критический удар (%)",
    STAT_HASTE = "Скорость (%)",
    STAT_MASTERY = "Искусность (%)",
    STAT_VERSATILITY = "Универсальность (%)",
    STAT_LEECH = "Самоисцеление (%)",
    STAT_AVOIDANCE = "Избежание (%)",
    STAT_SPEED = "Скорость передвижения (%)",
    STAT_INTELLECT = "Интеллект",
    STAT_AGILITY = "Ловкость",
    STAT_STRENGTH = "Сила",
    STAT_STAMINA = "Выносливость",
    STAT_ILVL = "Уровень предмета (ilvl)",
    STAT_ARMOR = "Броня",

    -- Slots
    Slot_HEAD = "Голова",
    Slot_NECK = "Шея",
    Slot_SHOULDER = "Плечи",
    Slot_BACK = "Спина",
    Slot_CHEST = "Грудь",
    Slot_WRIST = "Запястья",
    Slot_HANDS = "Кисти рук",
    Slot_WAIST = "Пояс",
    Slot_LEGS = "Поножи",
    Slot_FEET = "Ступни",
    Slot_FINGER1 = "Палец 1",
    Slot_FINGER2 = "Палец 2",
    Slot_TRINKET1 = "Аксессуар 1",
    Slot_TRINKET2 = "Аксессуар 2",
    Slot_MAINHAND = "Правая рука",
    Slot_OFFHAND = "Левая рука",
}

-- Select correct translations
local currentLocale = (locale == "ruRU") and ruRU or enUS

for k, v in pairs(currentLocale) do
    L[k] = v
end

-- Fallback to English if key is missing in Russian
if locale == "ruRU" then
    for k, v in pairs(enUS) do
        if not L[k] then
            L[k] = v
        end
    end
end
