-- Ratings.lua for EquipOptimizer
local addonName, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core

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
local DR_TIERS = {
    { limit = 30, penalty = 1.0 },
    { limit = 39, penalty = 0.9 },
    { limit = 47, penalty = 0.8 },
    { limit = 54, penalty = 0.7 },
    { limit = 66, penalty = 0.6 },
    { limit = 78, penalty = 0.5 }
}
ItemEvaluator.DR_TIERS = DR_TIERS

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

-- Get combat rating conversion factors dynamically from character sheet
function ItemEvaluator:GetRatingPerPercent(ratingIndex)
    local rating = GetCombatRating(ratingIndex) or 0
    local percent = GetCombatRatingBonus(ratingIndex) or 0
    if percent > 0 then
        return rating / percent
    end
    
    -- Fallback levels based on WoW 11.x / 12.x scaling
    local level = UnitLevel("player") or 80
    if level >= 80 then
        if ratingIndex == CR_HASTE then return 660
        elseif ratingIndex == CR_CRIT then return 700
        elseif ratingIndex == CR_MASTERY then return 700
        elseif ratingIndex == CR_VERSATILITY then return 780
        end
    elseif level >= 70 then
        if ratingIndex == CR_HASTE then return 170
        elseif ratingIndex == CR_CRIT then return 180
        elseif ratingIndex == CR_MASTERY then return 180
        elseif ratingIndex == CR_VERSATILITY then return 205
        end
    end
    return 100 -- ultimate fallback
end

-- Get dynamic base rating cost for secondary stats or fallback to level 90 (Midnight)
function ItemEvaluator:GetBaseRatingCost(statKey, combatRatingID)
    local rating = GetCombatRating and GetCombatRating(combatRatingID) or 0
    local percent = GetCombatRatingBonus and GetCombatRatingBonus(combatRatingID) or 0
    if percent > 0 and percent < 30 then
        return rating / percent
    end
    
    -- Hardcoded constants for lvl 90 (Midnight)
    if statKey == "STAT_CRIT" then
        return 1400
    elseif statKey == "STAT_HASTE" then
        return 1320
    elseif statKey == "STAT_MASTERY" then
        return 1400
    elseif statKey == "STAT_VERSATILITY" then
        return 1560
    end
    
    return 1400 -- fallback
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
    
    -- Secondary stats mapping
    local combatRatingID = nil
    if statKey == "STAT_CRIT" then
        combatRatingID = CR_CRIT
    elseif statKey == "STAT_HASTE" then
        combatRatingID = CR_HASTE
    elseif statKey == "STAT_MASTERY" then
        combatRatingID = CR_MASTERY
    elseif statKey == "STAT_VERSATILITY" then
        combatRatingID = CR_VERSATILITY
    end
    
    if not combatRatingID then
        return targetPercent
    end
    
    local baseCost = self:GetBaseRatingCost(statKey, combatRatingID)
    
    -- Piecewise linear diminishing returns calculation
    local remaining = targetPercent
    local totalRating = 0
    local prevLimit = 0
    
    for _, tier in ipairs(DR_TIERS) do
        local tierSize = tier.limit - prevLimit
        if remaining > tierSize then
            totalRating = totalRating + (tierSize * baseCost / tier.penalty)
            remaining = remaining - tierSize
            prevLimit = tier.limit
        else
            totalRating = totalRating + (remaining * baseCost / tier.penalty)
            remaining = 0
            break
        end
    end
    
    if remaining > 0 then
        local lastPenalty = DR_TIERS[#DR_TIERS].penalty
        totalRating = totalRating + (remaining * baseCost / lastPenalty)
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

