-- RatingsScanner.lua for EquipOptimizer
local _, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

-- Helper to strip enchants and gems from item link
function ItemEvaluator:GetCleanItemLink(itemLink)
    if not itemLink then return nil end
    local itemString = string.match(itemLink, "item:([%-?%d:]+)")
    if not itemString then return itemLink end
    
    local parts = {}
    local hasGemsOrEnchants = false
    local idx = 1
    for part in string.gmatch(itemString .. ":", "([^:]*):") do
        table.insert(parts, part)
        if idx >= 2 and idx <= 6 and part ~= "" and part ~= "0" then
            hasGemsOrEnchants = true
        end
        idx = idx + 1
    end
    
    if not hasGemsOrEnchants then
        return itemLink
    end
    
    if #parts >= 6 then
        parts[2] = "0" -- enchantID
        parts[3] = "0" -- gemID1
        parts[4] = "0" -- gemID2
        parts[5] = "0" -- gemID3
        parts[6] = "0" -- gemID4
    end
    
    local cleanItemString = table.concat(parts, ":")
    local cleanLink = string.gsub(itemLink, "item:[%-?%d:]+", "item:" .. cleanItemString)
    return cleanLink
end

-- Scrap stats and item level of a clean item (excluding socketed gems and enchants)
function ItemEvaluator:GetItemRatings(itemLink)
    local cleanLink = self:GetCleanItemLink(itemLink) or itemLink
    local GetItemStats = C_Item and C_Item.GetItemStats or _G.GetItemStats
    local rawStats = GetItemStats(cleanLink)
    local ratings = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_INTELLECT = 0,
        STAT_AGILITY = 0,
        STAT_STRENGTH = 0,
        STAT_STAMINA = 0,
        STAT_ARMOR = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
        STAT_ILVL = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
    }
    if rawStats then
        for rawKey, val in pairs(rawStats) do
            local mapped = self.StatKeyMapping[rawKey]
            if mapped then
                ratings[mapped] = ratings[mapped] + val
            end
        end
    end
    
    return ratings
end

-- Get the stats of enchants and gems currently on the item link
function ItemEvaluator:GetItemGemsAndEnchantsStats(itemLink)
    local stats = {
        STAT_CRIT = 0, STAT_HASTE = 0, STAT_MASTERY = 0, STAT_VERSATILITY = 0,
        STAT_INTELLECT = 0, STAT_AGILITY = 0, STAT_STRENGTH = 0, STAT_STAMINA = 0,
        STAT_LEECH = 0, STAT_AVOIDANCE = 0, STAT_SPEED = 0, STAT_ARMOR = 0,
    }
    local GetItemStats = C_Item and C_Item.GetItemStats or _G.GetItemStats
    if not GetItemStats then return stats end
    
    local dirty = GetItemStats(itemLink)
    local cleanLink = self:GetCleanItemLink(itemLink)
    local clean = cleanLink and GetItemStats(cleanLink)
    if dirty then
        for rawKey, dirtyVal in pairs(dirty) do
            local mapped = self.StatKeyMapping[rawKey]
            if mapped then
                local cleanVal = clean and clean[rawKey] or 0
                local diff = dirtyVal - cleanVal
                if diff > 0 then
                    stats[mapped] = stats[mapped] + diff
                end
            end
        end
    end
    return stats
end

-- Get the total stats of currently equipped items
function ItemEvaluator:GetEquippedStats()
    local stats = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
        STAT_INTELLECT = 0,
        STAT_AGILITY = 0,
        STAT_STRENGTH = 0,
        STAT_STAMINA = 0,
        STAT_ARMOR = 0,
    }
    for _, item in pairs(self.equipped or {}) do
        if item.ratings then
            for k in pairs(stats) do
                stats[k] = stats[k] + (item.ratings[k] or 0)
            end
        end
    end
    return stats
end

-- Get the total stats of enchants and gems currently on the equipped items
function ItemEvaluator:GetEquippedGemsAndEnchantsStats()
    local stats = {
        STAT_CRIT = 0, STAT_HASTE = 0, STAT_MASTERY = 0, STAT_VERSATILITY = 0,
        STAT_INTELLECT = 0, STAT_AGILITY = 0, STAT_STRENGTH = 0, STAT_STAMINA = 0,
        STAT_LEECH = 0, STAT_AVOIDANCE = 0, STAT_SPEED = 0, STAT_ARMOR = 0,
    }
    if not GetInventoryItemLink then return stats end
    
    local GetItemStats = C_Item and C_Item.GetItemStats or _G.GetItemStats
    if not GetItemStats then return stats end
    
    for slotId = 1, 19 do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            local dirty = GetItemStats(itemLink)
            local cleanLink = self:GetCleanItemLink(itemLink)
            local clean = cleanLink and GetItemStats(cleanLink)
            if dirty then
                for rawKey, dirtyVal in pairs(dirty) do
                    local mapped = self.StatKeyMapping[rawKey]
                    if mapped then
                        local cleanVal = clean and clean[rawKey] or 0
                        local diff = dirtyVal - cleanVal
                        if diff > 0 then
                            stats[mapped] = stats[mapped] + diff
                        end
                    end
                end
            end
        end
    end
    return stats
end

-- Get player current stats including gems/enchants but excluding temporary buffs
function ItemEvaluator:GetPlayerCurrentStats()
    local eqClean = self:GetEquippedStats()
    local gemsEnchants = self:GetEquippedGemsAndEnchantsStats()
    
    local intellect = 0
    local agility = 0
    local strength = 0
    local stamina = 0
    local armor = 0
    
    if UnitStat then
        local baseStr = select(1, UnitStat("player", 1)) or 0
        local baseAgi = select(1, UnitStat("player", 2)) or 0
        local baseSta = select(1, UnitStat("player", 3)) or 0
        local baseInt = select(1, UnitStat("player", 4)) or 0
        
        strength = baseStr + (eqClean.STAT_STRENGTH or 0) + (gemsEnchants.STAT_STRENGTH or 0)
        agility = baseAgi + (eqClean.STAT_AGILITY or 0) + (gemsEnchants.STAT_AGILITY or 0)
        stamina = baseSta + (eqClean.STAT_STAMINA or 0) + (gemsEnchants.STAT_STAMINA or 0)
        intellect = baseInt + (eqClean.STAT_INTELLECT or 0) + (gemsEnchants.STAT_INTELLECT or 0)
    end
    
    if UnitArmor then
        local baseArmor = select(1, UnitArmor("player")) or 0
        armor = baseArmor + (eqClean.STAT_ARMOR or 0) + (gemsEnchants.STAT_ARMOR or 0)
    end
    
    local avgIlvl = 0
    if GetAverageItemLevel then
        local _, val = GetAverageItemLevel()
        avgIlvl = val or 0
    end
    
    local crit = GetCombatRating and GetCombatRating(self.CR_CRIT) or ((eqClean.STAT_CRIT or 0) + (gemsEnchants.STAT_CRIT or 0))
    local haste = GetCombatRating and GetCombatRating(self.CR_HASTE) or ((eqClean.STAT_HASTE or 0) + (gemsEnchants.STAT_HASTE or 0))
    local mastery = GetCombatRating and GetCombatRating(self.CR_MASTERY) or ((eqClean.STAT_MASTERY or 0) + (gemsEnchants.STAT_MASTERY or 0))
    local versatility = GetCombatRating and GetCombatRating(self.CR_VERSATILITY) or ((eqClean.STAT_VERSATILITY or 0) + (gemsEnchants.STAT_VERSATILITY or 0))
    local leech = GetCombatRating and GetCombatRating(self.CR_LIFESTEAL) or ((eqClean.STAT_LEECH or 0) + (gemsEnchants.STAT_LEECH or 0))
    local avoidance = GetCombatRating and GetCombatRating(self.CR_AVOIDANCE) or ((eqClean.STAT_AVOIDANCE or 0) + (gemsEnchants.STAT_AVOIDANCE or 0))
    local speed = GetCombatRating and GetCombatRating(self.CR_SPEED) or ((eqClean.STAT_SPEED or 0) + (gemsEnchants.STAT_SPEED or 0))

    return {
        STAT_CRIT = crit,
        STAT_HASTE = haste,
        STAT_MASTERY = mastery,
        STAT_VERSATILITY = versatility,
        STAT_LEECH = leech,
        STAT_AVOIDANCE = avoidance,
        STAT_SPEED = speed,
        STAT_INTELLECT = intellect,
        STAT_AGILITY = agility,
        STAT_STRENGTH = strength,
        STAT_STAMINA = stamina,
        STAT_ARMOR = armor,
        STAT_ILVL = avgIlvl,
    }
end

-- Calculate resulting player stats with a specific combination of items from scratch
function ItemEvaluator:GetResultingStats(combination, currentStats, ratingPerPercent)
    local netStats = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
        STAT_INTELLECT = 0,
        STAT_AGILITY = 0,
        STAT_STRENGTH = 0,
        STAT_STAMINA = 0,
        STAT_ARMOR = 0,
    }
    
    -- Check if combination has a 2H weapon in MainHand
    local has2H = false
    local mainHandItem = combination[16]
    if mainHandItem and mainHandItem.equipType == "INVTYPE_2HWEAPON" then
        has2H = true
    end
    
    for slotId, itemInfo in pairs(combination) do
        local actualItem = itemInfo
        if slotId == 17 and has2H then
            -- Force offhand to empty if wielding a 2H weapon, but set ilvl to main hand's ilvl
            actualItem = { ratings = { STAT_ILVL = mainHandItem.ilvl }, ilvl = mainHandItem.ilvl }
        end
        
        local equippedInfo = self.equipped[slotId]
        local eqRatings = equippedInfo and equippedInfo.ratings or {}
        local eqGemsEnchants = equippedInfo and equippedInfo.gemsAndEnchants or {}
        local eqPotential = equippedInfo and equippedInfo.potentialGemsStats or {}
        local newRatings = actualItem.ratings or {}
        local newGemsEnchants = actualItem.gemsAndEnchants or {}
        local newPotential = actualItem.potentialGemsStats or {}
        
        -- Sum up differences for all stats
        for k in pairs(netStats) do
            local eqVal = (eqRatings[k] or 0) + (eqGemsEnchants[k] or 0) + (eqPotential[k] or 0)
            local newVal = (newRatings[k] or 0) + (newGemsEnchants[k] or 0) + (newPotential[k] or 0)
            netStats[k] = netStats[k] + (newVal - eqVal)
        end
    end
    
    local resulting = {}
    for k, v in pairs(netStats) do
        resulting[k] = (currentStats[k] or 0) + v
    end
    
    -- Item level delta calculation
    local netIlvlDiff = 0
    for slotId, itemInfo in pairs(combination) do
        local actualItem = itemInfo
        if slotId == 17 and has2H then
            actualItem = { ratings = { STAT_ILVL = mainHandItem.ilvl }, ilvl = mainHandItem.ilvl }
        end
        local equippedInfo = self.equipped[slotId]
        local eqIlvl = equippedInfo and equippedInfo.ratings and equippedInfo.ratings.STAT_ILVL or 0
        local newIlvl = actualItem.ratings and actualItem.ratings.STAT_ILVL or 0
        netIlvlDiff = netIlvlDiff + (newIlvl - eqIlvl)
    end
    resulting.STAT_ILVL = currentStats.STAT_ILVL + (netIlvlDiff / 16)
    
    return resulting
end
