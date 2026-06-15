-- BagScanner.lua for EquipOptimizer
local _, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator





local bagCache = nil

function ItemEvaluator:ClearBagCache()
    bagCache = nil
end

function ItemEvaluator:BuildBagCache()
    bagCache = {}
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
                            C_Item.RequestLoadItemDataByID(itemID)
                        else
                            local ratings = self:GetItemRatings(itemLink)
                            local gemsAndEnchants = self:GetItemGemsAndEnchantsStats(itemLink)
                            local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
                            
                            -- Sum rating for sorting
                            local totalRating = 0
                            for _, val in pairs(ratings) do
                                totalRating = totalRating + val
                            end
                            
                            table.insert(bagCache, {
                                bag = bag,
                                slot = slot,
                                searchKey = string.format("%d-%d", bag, slot),
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

-- Find all candidate items in bags for a slot (uses cache)
function ItemEvaluator:GetBagItemsForSlot(slotId)
    local items = {}
    local slotTypes = self.SlotToTypes[slotId]
    if not slotTypes then return items end
    
    if not bagCache then
        self:BuildBagCache()
    end
    
    for _, item in ipairs(bagCache) do
        local matches = false
        for _, t in ipairs(slotTypes) do
            if item.equipType == t then
                matches = true
                break
            end
        end
        if matches then
            table.insert(items, item)
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
                        searchKey = string.format("eq-%d", eqSlotId),
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

-- Scan tooltip to find maximum number of items in a set (disabled to prevent localization issues)
function ItemEvaluator:GetItemSetMax(itemLink)
    return 5
end


