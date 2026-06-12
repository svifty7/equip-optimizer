-- BagScanner.lua for EquipOptimizer
local addonName, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

-- Scrap stats and item level of an item
function ItemEvaluator:GetItemRatings(itemLink)
    local GetItemStats = C_Item and C_Item.GetItemStats or _G.GetItemStats
    local rawStats = GetItemStats(itemLink)
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

-- Find all candidate items in bags for a slot
function ItemEvaluator:GetBagItemsForSlot(slotId)
    local items = {}
    local slotTypes = self.SlotToTypes[slotId]
    if not slotTypes then return items end
    
    local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = C_Item.GetItemInfoInstant(itemLink)
                if itemID and IsEquippableItem(itemLink) then
                    local _, _, _, _, _, _, _, _, equipType, _, _, _, _, _, _, setID = GetItemInfo(itemID)
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
            local itemID = C_Item.GetItemInfoInstant(itemLink)
            local _, _, _, _, _, _, _, _, equipType, _, _, _, _, _, _, setID = GetItemInfo(itemID or itemLink)
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

-- Get the total secondary and tertiary stats of currently equipped items
function ItemEvaluator:GetEquippedStats()
    local stats = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
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

-- Calculate resulting player stats with a specific combination of items from scratch for secondary/tertiary stats
function ItemEvaluator:GetResultingStats(combination, currentStats, ratingPerPercent)
    local netStats = {
        STAT_INTELLECT = 0,
        STAT_AGILITY = 0,
        STAT_STRENGTH = 0,
        STAT_STAMINA = 0,
        STAT_ARMOR = 0,
        STAT_ILVL = 0,
    }
    
    local directStats = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
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
        local newRatings = actualItem.ratings or {}
        
        -- Delta for primary stats and ilvl
        for k in pairs(netStats) do
            local eqVal = eqRatings[k] or 0
            local newVal = newRatings[k] or 0
            netStats[k] = netStats[k] + (newVal - eqVal)
        end
        
        -- Direct sum for secondary and tertiary stats
        for k in pairs(directStats) do
            local newVal = newRatings[k] or 0
            directStats[k] = directStats[k] + newVal
        end
    end
    
    local resulting = {}
    
    -- Direct stats from items
    for k, v in pairs(directStats) do
        resulting[k] = v
    end
    
    -- Delta calculation for primary stats, armor, and item level
    resulting.STAT_INTELLECT = currentStats.STAT_INTELLECT + netStats.STAT_INTELLECT
    resulting.STAT_AGILITY = currentStats.STAT_AGILITY + netStats.STAT_AGILITY
    resulting.STAT_STRENGTH = currentStats.STAT_STRENGTH + netStats.STAT_STRENGTH
    resulting.STAT_STAMINA = currentStats.STAT_STAMINA + netStats.STAT_STAMINA
    resulting.STAT_ARMOR = currentStats.STAT_ARMOR + netStats.STAT_ARMOR
    resulting.STAT_ILVL = currentStats.STAT_ILVL + (netStats.STAT_ILVL / 16)
    
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
            local itemID = C_Item.GetItemInfoInstant(itemLink)
            local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemID or itemLink)
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
                    local itemID = C_Item.GetItemInfoInstant(itemLink)
                    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemID or itemLink)
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
            local itemID = C_Item.GetItemInfoInstant(itemLink)
            local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemID or itemLink)
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
                    local itemID = C_Item.GetItemInfoInstant(itemLink)
                    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemID or itemLink)
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


