-- BagScanner.lua for EquipOptimizer
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
        parts[2] = "" -- enchantID
        parts[3] = "" -- gemID1
        parts[4] = "" -- gemID2
        parts[5] = "" -- gemID3
        parts[6] = "" -- gemID4
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



-- Find all candidate items in bags for a slot
function ItemEvaluator:GetBagItemsForSlot(slotId)
    local items = {}
    local slotTypes = self.SlotToTypes[slotId]
    if not slotTypes then return items end
    
    local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    
    local numBags = NUM_BAG_SLOTS or 5
    for bag = 0, numBags do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local itemID = C_Item.GetItemInfoInstant(itemLink)
                    if itemID and IsEquippableItem(itemLink) then
                        local _, _, _, _, _, _, _, _, equipType, _, _, _, _, _, _, setID = GetItemInfo(itemLink)
                        if not equipType then
                            -- Async cache miss, request load
                            C_Item.RequestLoadItemDataByID(itemID)
                        else
                        local matches = false
                        for _, t in ipairs(slotTypes) do
                            if equipType == t then
                                matches = true
                                break
                            end
                        end
                        
                        if matches then
                            local ratings = self:GetItemRatings(itemLink)
                            local gemsAndEnchants = self:GetItemGemsAndEnchantsStats(itemLink)
                            local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
                            
                            -- Sum rating for sorting
                            local totalRating = 0
                            for _, val in pairs(ratings) do
                                totalRating = totalRating + val
                            end
                            
                            table.insert(items, {
                                bag = bag,
                                slot = slot,
                                link = itemLink,
                                ratings = ratings,
                                gemsAndEnchants = gemsAndEnchants,
                                ilvl = ilvl,
                                totalRating = totalRating,
                                equipType = equipType,
                                isEquipped = false,
                                setID = setID
                            })
                        end
                    end
                end
            end
        end
    end
    end
    return items
end

-- Find all equipped items that could fit a slot
function ItemEvaluator:GetEquippedItemsForSlot(slotId)
    local items = {}
    local slotTypes = self.SlotToTypes[slotId]
    if not slotTypes then return items end
    
    for eqSlotId, _ in pairs(self.SlotToTypes) do
        local itemLink = GetInventoryItemLink("player", eqSlotId)
        if itemLink then
            local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
            local _, _, _, _, _, _, _, _, equipType, _, _, _, _, _, _, setID = GetItemInfo(itemLink)
            if not equipType then
                _, _, _, equipType = C_Item.GetItemInfoInstant(itemLink)
            end
            if equipType then
                local matches = false
                for _, t in ipairs(slotTypes) do
                    if equipType == t then
                        matches = true
                        break
                    end
                end
                
                if matches then
                    local ratings = self:GetItemRatings(itemLink)
                    local gemsAndEnchants = self:GetItemGemsAndEnchantsStats(itemLink)
                    local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
                    
                    -- Sum rating for sorting
                    local totalRating = 0
                    for _, val in pairs(ratings) do
                        totalRating = totalRating + val
                    end
                    
                    table.insert(items, {
                        slotId = eqSlotId,
                        link = itemLink,
                        ratings = ratings,
                        gemsAndEnchants = gemsAndEnchants,
                        ilvl = ilvl,
                        totalRating = totalRating,
                        equipType = equipType,
                        isEquipped = true,
                        setID = setID
                    })
                end
            end
        end
    end
    return items
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
        strength = select(2, UnitStat("player", 1)) or 0
        agility = select(2, UnitStat("player", 2)) or 0
        stamina = select(2, UnitStat("player", 3)) or 0
        intellect = select(2, UnitStat("player", 4)) or 0
    end
    
    if UnitArmor then
        armor = select(2, UnitArmor("player")) or 0
    end
    
    local avgIlvl = 0
    if GetAverageItemLevel then
        local _, val = GetAverageItemLevel()
        avgIlvl = val or 0
    end
    
    return {
        STAT_CRIT = (eqClean.STAT_CRIT or 0) + (gemsEnchants.STAT_CRIT or 0),
        STAT_HASTE = (eqClean.STAT_HASTE or 0) + (gemsEnchants.STAT_HASTE or 0),
        STAT_MASTERY = (eqClean.STAT_MASTERY or 0) + (gemsEnchants.STAT_MASTERY or 0),
        STAT_VERSATILITY = (eqClean.STAT_VERSATILITY or 0) + (gemsEnchants.STAT_VERSATILITY or 0),
        STAT_LEECH = (eqClean.STAT_LEECH or 0) + (gemsEnchants.STAT_LEECH or 0),
        STAT_AVOIDANCE = (eqClean.STAT_AVOIDANCE or 0) + (gemsEnchants.STAT_AVOIDANCE or 0),
        STAT_SPEED = (eqClean.STAT_SPEED or 0) + (gemsEnchants.STAT_SPEED or 0),
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

-- Find all unique sets in bags and equipped slots
function ItemEvaluator:GetAvailableSets()
    local sets = {}
    local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local GetItemSetInfo = C_Item and C_Item.GetItemSetInfo or _G.GetItemSetInfo
    
    -- Scan equipped items
    for slotId = 1, 19 do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemLink)
            if setID and setID > 0 then
                sets[setID] = itemLink
            end
        end
    end
    
    -- Scan bags
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemLink)
                    if setID and setID > 0 then
                        sets[setID] = itemLink
                    end
                end
            end
        end
    end
    
    -- Convert to list with names
    local result = {}
    self.setMaxCache = self.setMaxCache or {}
    
    for setID, sampleLink in pairs(sets) do
        local setName, setTexture = GetItemSetInfo(setID)
        
        local maxItems = self.setMaxCache[setID]
        if not maxItems and sampleLink then
            maxItems = self:GetItemSetMax(sampleLink)
            if maxItems then
                self.setMaxCache[setID] = maxItems
            end
        end
        
        table.insert(result, {
            id = setID,
            name = setName or ("Set " .. tostring(setID)),
            texture = setTexture,
            maxItems = maxItems or 5
        })
    end
    
    table.sort(result, function(a, b)
        return a.name < b.name
    end)
    
    return result
end

-- Get counts of owned items for each set
function ItemEvaluator:GetOwnedSetCounts()
    local counts = {}
    local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    
    -- Equipped
    for slotId = 1, 19 do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemLink)
            if setID and setID > 0 then
                counts[setID] = (counts[setID] or 0) + 1
            end
        end
    end
    
    -- Bags
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemLink)
                    if setID and setID > 0 then
                        counts[setID] = (counts[setID] or 0) + 1
                    end
                end
            end
        end
    end
    return counts
end

-- Scan tooltip to find maximum number of items in a set
function ItemEvaluator:GetItemSetMax(itemLink)
    -- Try C_TooltipInfo first (modern Retail/Classic)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
        if tooltipData and tooltipData.lines then
            for i = 1, #tooltipData.lines do
                local line = tooltipData.lines[i]
                if line and line.leftText then
                    local _, maxVal = string.match(line.leftText, "%((%d+)%s*/%s*(%d+)%)")
                    if maxVal then
                        return tonumber(maxVal)
                    end
                end
            end
        end
    end
    
    -- Fallback to hidden tooltip scanner (older WoW / Classic fallback)
    if not self.tooltipScanner then
        self.tooltipScanner = CreateFrame("GameTooltip", "EquipOptimizerTooltipScanner", nil, "GameTooltipTemplate")
        self.tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    self.tooltipScanner:ClearLines()
    self.tooltipScanner:SetHyperlink(itemLink)
    for i = 1, self.tooltipScanner:NumLines() do
        local fontString = _G["EquipOptimizerTooltipScannerTextLeft" .. i]
        local text = fontString and fontString:GetText()
        if text then
            local _, maxVal = string.match(text, "%((%d+)%s*/%s*(%d+)%)")
            if maxVal then
                return tonumber(maxVal)
            end
        end
    end
    
    return nil
end


