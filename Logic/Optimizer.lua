-- Optimizer.lua for EquipOptimizer
local addonName, addonTable = ...
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator

-- Perform search for best items combo
function ItemEvaluator:Optimize()
    local profile = Core.activeProfile
    local activeRules = {}
    if profile.rules then
        for _, r in ipairs(profile.rules) do
            if r.enabled then
                table.insert(activeRules, r)
            end
        end
    end
    
    -- Extract current character sheet stats
    local _, avgIlvl = GetAverageItemLevel()
    
    local currentStats = {
        STAT_CRIT = GetCombatRating(self.CR_CRIT) or 0,
        STAT_HASTE = GetCombatRating(self.CR_HASTE) or 0,
        STAT_MASTERY = GetCombatRating(self.CR_MASTERY) or 0,
        STAT_VERSATILITY = GetCombatRating(self.CR_VERSATILITY) or 0,
        STAT_LEECH = GetCombatRating(self.CR_LIFESTEAL) or 0,
        STAT_AVOIDANCE = GetCombatRating(self.CR_AVOIDANCE) or 0,
        STAT_SPEED = GetCombatRating(self.CR_SPEED) or 0,
        STAT_INTELLECT = select(2, UnitStat("player", 4)) or 0,
        STAT_AGILITY = select(2, UnitStat("player", 2)) or 0,
        STAT_STRENGTH = select(2, UnitStat("player", 1)) or 0,
        STAT_STAMINA = select(2, UnitStat("player", 3)) or 0,
        STAT_ARMOR = select(2, UnitArmor("player")) or 0,
        STAT_ILVL = avgIlvl or 0,
    }
    
    local ratingPerPercent = {
        STAT_CRIT = self:GetRatingPerPercent(self.CR_CRIT),
        STAT_HASTE = self:GetRatingPerPercent(self.CR_HASTE),
        STAT_MASTERY = self:GetRatingPerPercent(self.CR_MASTERY),
        STAT_VERSATILITY = self:GetRatingPerPercent(self.CR_VERSATILITY),
    }
    
    -- Scan currently equipped items
    self.equipped = {}
    local candidates = {}
    
    for _, slotInfo in ipairs(Core.Slots) do
        local slotId = slotInfo.id
        candidates[slotId] = {}
        
        local itemLink = GetInventoryItemLink("player", slotId)
        local eqItem = nil
        if itemLink then
            local ratings = self:GetItemRatings(itemLink)
            local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
            local _, _, _, _, _, _, _, _, equipType = C_Item.GetItemInfo(itemLink)
            
            eqItem = {
                link = itemLink,
                ratings = ratings,
                ilvl = ilvl,
                equipType = equipType,
                isEquipped = true,
                slotId = slotId
            }
            self.equipped[slotId] = eqItem
        else
            eqItem = { ratings = {}, ilvl = 0, link = nil, isEquipped = true, slotId = slotId }
            self.equipped[slotId] = eqItem
        end
        
        -- Adjust offhand slot item level if wielding a 2H weapon
        if slotId == 17 then
            local mainHand = self.equipped[16]
            if mainHand and mainHand.equipType == "INVTYPE_2HWEAPON" then
                eqItem.ratings.STAT_ILVL = mainHand.ilvl
                eqItem.ilvl = mainHand.ilvl
            end
        end
        
        table.insert(candidates[slotId], eqItem)
        
        -- Lock evaluation logic
        local lockVal = profile.lockedSlots[slotId]
        if not lockVal then
            local bagItems = self:GetBagItemsForSlot(slotId)
            
            table.sort(bagItems, function(a, b)
                if a.ilvl ~= b.ilvl then
                    return a.ilvl > b.ilvl
                end
                return a.totalRating > b.totalRating
            end)
            
            local limit = (slotId == 11 or slotId == 12 or slotId == 13 or slotId == 14 or slotId == 16 or slotId == 17) and 4 or 2
            
            local maxIlvl = eqItem.ilvl
            if #bagItems > 0 and bagItems[1].ilvl > maxIlvl then
                maxIlvl = bagItems[1].ilvl
            end
            
            local count = 0
            for _, item in ipairs(bagItems) do
                local allowedDiff = (slotId == 11 or slotId == 12 or slotId == 13 or slotId == 14) and 30 or 15
                if item.ilvl >= (maxIlvl - allowedDiff) then
                    table.insert(candidates[slotId], item)
                    count = count + 1
                    if count >= limit then break end
                end
            end
        else
            -- Slot IS locked!
            candidates[slotId] = {}
            if lockVal == true or lockVal == "equipped" then
                table.insert(candidates[slotId], eqItem)
            else
                -- It is a specific item link chosen by user
                local bagItems = self:GetBagItemsForSlot(slotId)
                local found = false
                for _, item in ipairs(bagItems) do
                    if item.link == lockVal then
                        table.insert(candidates[slotId], item)
                        found = true
                        break
                    end
                end
                if not found then
                    -- Check if it's currently equipped in any slot that fits
                    local equippedItems = self:GetEquippedItemsForSlot(slotId)
                    for _, item in ipairs(equippedItems) do
                        if item.link == lockVal then
                            table.insert(candidates[slotId], item)
                            found = true
                            break
                        end
                    end
                end
                if not found then
                    -- Fallback if selected item is no longer in bag/equipped
                    table.insert(candidates[slotId], eqItem)
                end
            end
        end
    end
    
    local eqStats = self:GetEquippedStats()
    for k, v in pairs(eqStats) do
        currentStats[k] = v
    end
    
    -- Filter optimizable slots
    local optimizableSlots = {}
    local currentComb = {}
    
    for slotId, slotCandidates in pairs(candidates) do
        if #slotCandidates == 1 then
            currentComb[slotId] = slotCandidates[1]
        else
            table.insert(optimizableSlots, slotId)
        end
    end
    
    -- Safety throttle to prevent freezing (cap total combinations)
    local totalCombinations = 1
    for _, slotId in ipairs(optimizableSlots) do
        totalCombinations = totalCombinations * #candidates[slotId]
    end
    
    if totalCombinations > 5000 then
        -- Prune candidates to top 1 bag item per slot
        for _, slotId in ipairs(optimizableSlots) do
            if #candidates[slotId] > 2 then
                candidates[slotId] = { candidates[slotId][1], candidates[slotId][2] }
            end
        end
    end
    
    -- Combinations search
    local bestCombination = nil
    
    local function GenerateCombinations(optIndex, usedBagItems)
        if optIndex > #optimizableSlots then
            -- Validate: 2H weapon vs OffHand
            local mainHand = currentComb[16]
            local offHand = currentComb[17]
            if mainHand and mainHand.equipType == "INVTYPE_2HWEAPON" then
                -- With 2H weapon, we only evaluate once using the first candidate of slot 17 to avoid duplicates
                if offHand ~= candidates[17][1] then
                    return
                end
            end
            
            -- Compute stats
            local stats = self:GetResultingStats(currentComb, currentStats, ratingPerPercent)
            local combNode = {
                items = {},
                stats = stats
            }
            for k, v in pairs(currentComb) do
                combNode.items[k] = v
            end
            
            if not bestCombination then
                bestCombination = combNode
            else
                if self:CompareCombinations(combNode, bestCombination, activeRules) then
                    bestCombination = combNode
                end
            end
            return
        end
        
        local slotId = optimizableSlots[optIndex]
        local slotCandidates = candidates[slotId]
        
        for _, cand in ipairs(slotCandidates) do
            local key = cand.bag and string.format("%d-%d", cand.bag, cand.slot) or (cand.isEquipped and cand.slotId and string.format("eq-%d", cand.slotId) or nil)
            if not key or not usedBagItems[key] then
                if key then usedBagItems[key] = true end
                currentComb[slotId] = cand
                
                GenerateCombinations(optIndex + 1, usedBagItems)
                
                currentComb[slotId] = nil
                if key then usedBagItems[key] = nil end
            end
        end
    end
    
    -- Start combination traversal
    local usedBagItems = {}
    GenerateCombinations(1, usedBagItems)
    
    -- Build recommendations list
    local recommendations = {}
    if bestCombination then
        local has2H = false
        local mainHandItem = bestCombination.items[16]
        if mainHandItem and mainHandItem.equipType == "INVTYPE_2HWEAPON" then
            has2H = true
        end
        
        for slotId, itemInfo in pairs(bestCombination.items) do
            local eqItem = self.equipped[slotId]
            local recItem = itemInfo
            
            if slotId == 17 and has2H then
                -- Off-hand must be empty if wielding a 2H weapon
                recItem = { link = nil, ilvl = 0, bag = nil, slot = nil }
            end
            
            -- If recommend item is different from equipped item
            if recItem.link ~= (eqItem and eqItem.link) then
                recommendations[slotId] = {
                    slotId = slotId,
                    currentLink = eqItem and eqItem.link or nil,
                    recommendedLink = recItem.link,
                    bag = recItem.bag,
                    slot = recItem.slot,
                    equippedSlot = recItem.isEquipped and recItem.slotId or nil,
                    ilvlDiff = recItem.ilvl - (eqItem and eqItem.ilvl or 0)
                }
            end
        end
    end
    
    return recommendations, bestCombination and bestCombination.stats or currentStats
end
