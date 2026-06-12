-- GemDB.lua for EquipOptimizer
local _, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

local GemDB = {
    {
        ids = { 240966, 240967 },
        stats = { {STAT_PRIMARY=18}, {STAT_PRIMARY=23} },
        isMeta = true
    },
    {
        ids = { 240968, 240969 },
        stats = { {STAT_PRIMARY=18}, {STAT_PRIMARY=23} },
        isMeta = true
    },
    {
        ids = { 240970, 240971 },
        stats = { {STAT_PRIMARY=18, STAT_ARMOR=10}, {STAT_PRIMARY=23, STAT_ARMOR=13} },
        isMeta = true
    },
    {
        ids = { 240982, 240983 },
        stats = { {STAT_PRIMARY=26}, {STAT_PRIMARY=32} },
        isMeta = true
    },
    {
        ids = { 240897, 240898 },
        stats = { {STAT_MASTERY=14, STAT_CRIT=6}, {STAT_MASTERY=16, STAT_CRIT=7} }
    },
    {
        ids = { 240907, 240908 },
        stats = { {STAT_CRIT=14, STAT_MASTERY=6}, {STAT_CRIT=16, STAT_MASTERY=7} }
    },
    {
        ids = { 240905, 240906 },
        stats = { {STAT_CRIT=14, STAT_HASTE=6}, {STAT_CRIT=16, STAT_HASTE=7} }
    },
    {
        ids = { 240889, 240890 },
        stats = { {STAT_HASTE=14, STAT_CRIT=6}, {STAT_HASTE=16, STAT_CRIT=7} }
    },
    {
        ids = { 240891, 240892 },
        stats = { {STAT_HASTE=14, STAT_MASTERY=6}, {STAT_HASTE=16, STAT_MASTERY=7} }
    },
    {
        ids = { 240899, 240900 },
        stats = { {STAT_MASTERY=14, STAT_HASTE=6}, {STAT_MASTERY=16, STAT_HASTE=7} }
    },
    {
        ids = { 240893, 240894 },
        stats = { {STAT_HASTE=14, STAT_VERSATILITY=6}, {STAT_HASTE=16, STAT_VERSATILITY=7} }
    },
    {
        ids = { 240909, 240910 },
        stats = { {STAT_CRIT=14, STAT_VERSATILITY=6}, {STAT_CRIT=16, STAT_VERSATILITY=7} }
    },
    {
        ids = { 240915, 240916 },
        stats = { {STAT_VERSATILITY=14, STAT_HASTE=6}, {STAT_VERSATILITY=16, STAT_HASTE=7} }
    },
    {
        ids = { 240901, 240902 },
        stats = { {STAT_MASTERY=14, STAT_VERSATILITY=6}, {STAT_MASTERY=16, STAT_VERSATILITY=7} }
    },
    {
        ids = { 240917, 240918 },
        stats = { {STAT_VERSATILITY=14, STAT_MASTERY=6}, {STAT_VERSATILITY=16, STAT_MASTERY=7} }
    },
    {
        ids = { 240913, 240914 },
        stats = { {STAT_VERSATILITY=14, STAT_CRIT=6}, {STAT_VERSATILITY=16, STAT_CRIT=7} }
    },
    {
        ids = { 240903, 240904 },
        stats = { {STAT_CRIT=15}, {STAT_CRIT=17} }
    },
    {
        ids = { 240895, 240896 },
        stats = { {STAT_MASTERY=15}, {STAT_MASTERY=17} }
    },
    {
        ids = { 240887, 240888 },
        stats = { {STAT_HASTE=15}, {STAT_HASTE=17} }
    },
    {
        ids = { 240865, 240866 },
        stats = { {STAT_MASTERY=11, STAT_CRIT=4}, {STAT_MASTERY=12, STAT_CRIT=5} }
    },
    {
        ids = { 240877, 240878 },
        stats = { {STAT_CRIT=11, STAT_VERSATILITY=4}, {STAT_CRIT=12, STAT_VERSATILITY=5} }
    },
    {
        ids = { 240911, 240912 },
        stats = { {STAT_VERSATILITY=15}, {STAT_VERSATILITY=17} }
    },
    {
        ids = { 240873, 240874 },
        stats = { {STAT_CRIT=11, STAT_HASTE=4}, {STAT_CRIT=12, STAT_HASTE=5} }
    },
    {
        ids = { 240859, 240860 },
        stats = { {STAT_HASTE=11, STAT_MASTERY=4}, {STAT_HASTE=12, STAT_MASTERY=5} }
    },
    {
        ids = { 240855, 240856 },
        stats = { {STAT_HASTE=12}, {STAT_HASTE=13} }
    },
    {
        ids = { 240861, 240862 },
        stats = { {STAT_HASTE=11, STAT_VERSATILITY=4}, {STAT_HASTE=12, STAT_VERSATILITY=5} }
    },
    {
        ids = { 240871, 240872 },
        stats = { {STAT_CRIT=12}, {STAT_CRIT=13} }
    },
    {
        ids = { 240867, 240868 },
        stats = { {STAT_MASTERY=11, STAT_HASTE=4}, {STAT_MASTERY=12, STAT_HASTE=5} }
    },
    {
        ids = { 240875, 240876 },
        stats = { {STAT_CRIT=11, STAT_MASTERY=4}, {STAT_CRIT=12, STAT_MASTERY=5} }
    },
    {
        ids = { 240869, 240870 },
        stats = { {STAT_MASTERY=11, STAT_VERSATILITY=4}, {STAT_MASTERY=12, STAT_VERSATILITY=5} }
    },
    {
        ids = { 240857, 240858 },
        stats = { {STAT_HASTE=11, STAT_CRIT=4}, {STAT_HASTE=12, STAT_CRIT=5} }
    },
    {
        ids = { 240863, 240864 },
        stats = { {STAT_MASTERY=12}, {STAT_MASTERY=13} }
    },
    {
        ids = { 240885, 240886 },
        stats = { {STAT_VERSATILITY=11, STAT_MASTERY=4}, {STAT_VERSATILITY=12, STAT_MASTERY=5} }
    },
    {
        ids = { 240881, 240882 },
        stats = { {STAT_VERSATILITY=11, STAT_CRIT=4}, {STAT_VERSATILITY=12, STAT_CRIT=5} }
    },
    {
        ids = { 240883, 240884 },
        stats = { {STAT_VERSATILITY=11, STAT_HASTE=4}, {STAT_VERSATILITY=12, STAT_HASTE=5} }
    },
    {
        ids = { 240879, 240880 },
        stats = { {STAT_VERSATILITY=12}, {STAT_VERSATILITY=13} }
    },
}

ItemEvaluator.GemDB = GemDB
