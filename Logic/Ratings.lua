-- Ratings.lua for EquipOptimizer
local _, addonTable = ...

local ItemEvaluator = {}
addonTable.ItemEvaluator = ItemEvaluator

-- Constants for combat ratings
local CR_CRIT = 9
local CR_HASTE = 18
local CR_MASTERY = 26
local CR_VERSATILITY = 29
local CR_SPEED = 13
local CR_AVOIDANCE = 14
local CR_LIFESTEAL = 17

ItemEvaluator.CR_CRIT = CR_CRIT
ItemEvaluator.CR_HASTE = CR_HASTE
ItemEvaluator.CR_MASTERY = CR_MASTERY
ItemEvaluator.CR_VERSATILITY = CR_VERSATILITY
ItemEvaluator.CR_SPEED = CR_SPEED
ItemEvaluator.CR_AVOIDANCE = CR_AVOIDANCE
ItemEvaluator.CR_LIFESTEAL = CR_LIFESTEAL

-- Base rating costs for tertiary stats (strictly linear, no DR)
local TERTIARY_BASE_COSTS = {
    STAT_LEECH = 1100,
    STAT_AVOIDANCE = 1100,
    STAT_SPEED = 1100,
    Leech = 1100,
    Avoidance = 1100,
    Speed = 1100,
}
ItemEvaluator.TERTIARY_BASE_COSTS = TERTIARY_BASE_COSTS

-- Diminishing returns tiers for secondary stats (percent limit, penalty multiplier)
local STAT_DR_INFO = {
    STAT_CRIT = {
        baseCost = 138,
        tiers = {
            { limit = 1380, penalty = 1.0 },
            { limit = 1840, penalty = 0.9 },
            { limit = 2300, penalty = 0.8 },
        },
        lastPenalty = 0.7
    },
    STAT_HASTE = {
        baseCost = 132,
        tiers = {
            { limit = 1320, penalty = 1.0 },
            { limit = 1760, penalty = 0.9 },
            { limit = 2200, penalty = 0.8 },
        },
        lastPenalty = 0.7
    },
    STAT_MASTERY = {
        baseCost = 138,
        tiers = {
            { limit = 1380, penalty = 1.0 },
            { limit = 1840, penalty = 0.9 },
            { limit = 2300, penalty = 0.8 },
        },
        lastPenalty = 0.7
    },
    STAT_VERSATILITY = {
        baseCost = 162,
        tiers = {
            { limit = 1620, penalty = 1.0 },
            { limit = 2160, penalty = 0.9 },
            { limit = 2700, penalty = 0.8 },
        },
        lastPenalty = 0.7
    }
}
ItemEvaluator.STAT_DR_INFO = STAT_DR_INFO

-- Stat key mapping from GetItemStats keys to internal keys
local StatKeyMapping = {}
local mappingDefinition = {
    -- Secondary stats
    ITEM_MOD_CRIT_RATING_SHORT = "STAT_CRIT",
    ITEM_MOD_CRIT_MELEE_SHORT = "STAT_CRIT",
    ITEM_MOD_CRIT_RANGED_SHORT = "STAT_CRIT",
    ITEM_MOD_CRIT_SPELL_SHORT = "STAT_CRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "STAT_HASTE",
    ITEM_MOD_HASTE_SHORT = "STAT_HASTE",
    ITEM_MOD_MASTERY_RATING_SHORT = "STAT_MASTERY",
    ITEM_MOD_MASTERY_SHORT = "STAT_MASTERY",
    ITEM_MOD_VERSATILITY = "STAT_VERSATILITY",
    
    -- Primary stats
    ITEM_MOD_INTELLECT_SHORT = "STAT_INTELLECT",
    ITEM_MOD_INTELLECT = "STAT_INTELLECT",
    ITEM_MOD_AGILITY_SHORT = "STAT_AGILITY",
    ITEM_MOD_AGILITY = "STAT_AGILITY",
    ITEM_MOD_STRENGTH_SHORT = "STAT_STRENGTH",
    ITEM_MOD_STRENGTH = "STAT_STRENGTH",
    ITEM_MOD_STAMINA_SHORT = "STAT_STAMINA",
    ITEM_MOD_STAMINA = "STAT_STAMINA",
    ITEM_MOD_ARMOR_SHORT = "STAT_ARMOR",
    ITEM_MOD_ARMOR = "STAT_ARMOR",
    RESISTANCE0_NAME = "STAT_ARMOR",
    
    -- Tertiary stats
    ITEM_MOD_CR_LIFESTEAL_SHORT = "STAT_LEECH",
    ITEM_MOD_CR_LIFESTEAL = "STAT_LEECH",
    ITEM_MOD_CR_AVOIDANCE_SHORT = "STAT_AVOIDANCE",
    ITEM_MOD_CR_AVOIDANCE = "STAT_AVOIDANCE",
    ITEM_MOD_CR_SPEED_SHORT = "STAT_SPEED",
    ITEM_MOD_CR_SPEED = "STAT_SPEED",
}

for constName, internalKey in pairs(mappingDefinition) do
    StatKeyMapping[constName] = internalKey
    local locVal = _G[constName]
    if locVal and type(locVal) == "string" then
        StatKeyMapping[locVal] = internalKey
    end
end
ItemEvaluator.StatKeyMapping = StatKeyMapping

-- Slot ID to inventory types mapping
local SlotToTypes = {
    [1] = { "INVTYPE_HEAD" },
    [2] = { "INVTYPE_NECK" },
    [3] = { "INVTYPE_SHOULDER" },
    [15] = { "INVTYPE_BACK" },
    [5] = { "INVTYPE_CHEST", "INVTYPE_ROBE" },
    [9] = { "INVTYPE_WRIST" },
    [10] = { "INVTYPE_HAND" },
    [6] = { "INVTYPE_WAIST" },
    [7] = { "INVTYPE_LEGS" },
    [8] = { "INVTYPE_FEET" },
    [11] = { "INVTYPE_FINGER" },
    [12] = { "INVTYPE_FINGER" },
    [13] = { "INVTYPE_TRINKET" },
    [14] = { "INVTYPE_TRINKET" },
    [16] = { "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" },
    [17] = { "INVTYPE_WEAPON", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" }
}
ItemEvaluator.SlotToTypes = SlotToTypes

-- Get combat rating conversion factors statically for lvl 90 (Midnight)
function ItemEvaluator:GetRatingPerPercent(ratingIndex)
    if ratingIndex == CR_HASTE then return 132
    elseif ratingIndex == CR_CRIT then return 138
    elseif ratingIndex == CR_MASTERY then return 138
    elseif ratingIndex == CR_VERSATILITY then return 162
    end
    return 100 -- ultimate fallback
end

-- Get static base rating cost for secondary stats for lvl 90 (Midnight)
function ItemEvaluator:GetBaseRatingCost(statKey, combatRatingID)
    local info = STAT_DR_INFO[statKey]
    if info then return info.baseCost end
    if statKey == "STAT_CRIT" then return 138
    elseif statKey == "STAT_HASTE" then return 132
    elseif statKey == "STAT_MASTERY" then return 138
    elseif statKey == "STAT_VERSATILITY" then return 162
    end
    return 138 -- fallback
end

-- Convert rating to percent with piecewise diminishing returns
function ItemEvaluator:ConvertRatingToPercent(statKey, rating)
    if not rating or rating <= 0 then
        return 0
    end
    
    local info = STAT_DR_INFO[statKey]
    if not info then
        local cost = self.TERTIARY_BASE_COSTS[statKey] or 1100
        return rating / cost
    end
    
    local baseCost = info.baseCost
    local remaining = rating
    local totalPercent = 0
    local prevLimit = 0
    
    for _, tier in ipairs(info.tiers) do
        local tierSize = tier.limit - prevLimit
        if remaining > tierSize then
            totalPercent = totalPercent + (tierSize * tier.penalty / baseCost)
            remaining = remaining - tierSize
            prevLimit = tier.limit
        else
            totalPercent = totalPercent + (remaining * tier.penalty / baseCost)
            remaining = 0
            break
        end
    end
    
    if remaining > 0 then
        totalPercent = totalPercent + (remaining * info.lastPenalty / baseCost)
    end
    
    return totalPercent
end

-- Convert target percent to target rating with piecewise diminishing returns
function ItemEvaluator:ConvertPercentToRating(statKey, targetPercent)
    if not targetPercent or targetPercent <= 0 then
        return 0
    end
    
    -- Check if it's a tertiary stat
    local tertiaryCost = TERTIARY_BASE_COSTS[statKey]
    if tertiaryCost then
        return targetPercent * tertiaryCost
    end
    
    local info = STAT_DR_INFO[statKey]
    if not info then
        return targetPercent
    end
    
    local baseCost = info.baseCost
    local remaining = targetPercent
    local totalRating = 0
    local prevLimitPercent = 0
    local prevLimitRating = 0
    
    for _, tier in ipairs(info.tiers) do
        local tierSizeRating = tier.limit - prevLimitRating
        local tierSizePercent = (tierSizeRating * tier.penalty) / baseCost
        if remaining > tierSizePercent then
            totalRating = totalRating + tierSizeRating
            remaining = remaining - tierSizePercent
            prevLimitRating = tier.limit
        else
            totalRating = totalRating + (remaining * baseCost / tier.penalty)
            remaining = 0
            break
        end
    end
    
    if remaining > 0 then
        totalRating = totalRating + (remaining * baseCost / info.lastPenalty)
    end
    
    return totalRating
end

-- Get base percentages (total sheet percentage minus rating percentage)
function ItemEvaluator:GetBaseStatPercentages()
    local basePct = {
        STAT_HASTE = 0,
        STAT_CRIT = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
    }
    
    if GetHaste then
        local rating = GetCombatRating(self.CR_HASTE) or 0
        local rating_per_percent = self:GetRatingPerPercent(self.CR_HASTE)
        local rating_pct = rating_per_percent > 0 and (rating / rating_per_percent) or 0
        basePct.STAT_HASTE = GetHaste() - rating_pct
    end
    
    if GetCritChance then
        local rating = GetCombatRating(self.CR_CRIT) or 0
        local rating_per_percent = self:GetRatingPerPercent(self.CR_CRIT)
        local rating_pct = rating_per_percent > 0 and (rating / rating_per_percent) or 0
        basePct.STAT_CRIT = GetCritChance() - rating_pct
    end
    
    if GetMasteryEffect then
        local rating = GetCombatRating(self.CR_MASTERY) or 0
        local rating_per_percent = self:GetRatingPerPercent(self.CR_MASTERY)
        local rating_pct = rating_per_percent > 0 and (rating / rating_per_percent) or 0
        basePct.STAT_MASTERY = GetMasteryEffect() - rating_pct
    end
    
    return basePct
end

