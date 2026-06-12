-- Optimizer.lua for EquipOptimizer
local _, addonTable = ...
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local L = addonTable.L

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
    
    local ratingPerPercent = {
        STAT_CRIT = self:GetRatingPerPercent(self.CR_CRIT),
        STAT_HASTE = self:GetRatingPerPercent(self.CR_HASTE),
        STAT_MASTERY = self:GetRatingPerPercent(self.CR_MASTERY),
        STAT_VERSATILITY = self:GetRatingPerPercent(self.CR_VERSATILITY),
    }
    
    local bestGemStats = self:GetBestGemStats(activeRules)
    
    local function populatePotentialStats(item)
        if not item.link then 
            item.potentialGemsStats = {}
            return 
        end
        local socketsInfo = self:ParseItemSockets(item.link)
        item.totalSockets = socketsInfo and socketsInfo.totalSockets or 0
        local emptySockets = socketsInfo and socketsInfo.emptySockets or 0
        item.potentialGemsStats = {}
        for k, v in pairs(bestGemStats) do
            item.potentialGemsStats[k] = v * emptySockets
        end
    end
    
    
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
            local gemsAndEnchants = self:GetItemGemsAndEnchantsStats(itemLink)
            local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
            local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
            local itemID = C_Item.GetItemInfoInstant(itemLink)
            local _, _, _, _, _, _, _, _, equipType, _, _, _, _, _, _, setID = GetItemInfo(itemLink)
            if not equipType and itemID then
                C_Item.RequestLoadItemDataByID(itemID)
            end
            
            eqItem = {
                link = itemLink,
                ratings = ratings,
                gemsAndEnchants = gemsAndEnchants,
                ilvl = ilvl,
                equipType = equipType,
                isEquipped = true,
                slotId = slotId,
                setID = setID
            }
            populatePotentialStats(eqItem)
            self.equipped[slotId] = eqItem
        else
            eqItem = { ratings = {}, gemsAndEnchants = {}, ilvl = 0, link = nil, isEquipped = true, slotId = slotId, potentialGemsStats = {} }
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
            for _, item in ipairs(bagItems) do
                populatePotentialStats(item)
            end
            
            table.sort(bagItems, function(a, b)
                if a.ilvl ~= b.ilvl then
                    return a.ilvl > b.ilvl
                end
                for _, rule in ipairs(activeRules) do
                    local valA = a.ratings[rule.stat] or 0
                    local valB = b.ratings[rule.stat] or 0
                    if valA ~= valB then
                        -- For both MAX and >= rules, higher stats are better
                        return valA > valB
                    end
                end
                return a.totalRating > b.totalRating
            end)
            
            local limit = (slotId == 11 or slotId == 12 or slotId == 13 or slotId == 14 or slotId == 16 or slotId == 17) and 8 or 6
            
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
                for _, item in ipairs(bagItems) do
                    populatePotentialStats(item)
                end
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
                        populatePotentialStats(item)
                    end
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
    local adjustedRequiredSets = {}
    local hasInteractions = false
    for _, rule in ipairs(activeRules) do
        if rule.op == ">=" then
            hasInteractions = true
            break
        end
    end
    if profile.requiredSets then
        for _, count in pairs(profile.requiredSets) do
            if count > 0 then
                hasInteractions = true
                break
            end
        end
    end
    
    if not hasInteractions then
        for slotId, slotCandidates in pairs(candidates) do
            if slotId ~= 11 and slotId ~= 12 and slotId ~= 13 and slotId ~= 14 and slotId ~= 16 and slotId ~= 17 then
                if #slotCandidates > 1 then
                    local bestCand = slotCandidates[1]
                    local bestScore = -1
                    for _, cand in ipairs(slotCandidates) do
                        local candStats = {}
                        for k, v in pairs(cand.ratings or {}) do candStats[k] = v end
                        for k, v in pairs(cand.potentialGemsStats or {}) do candStats[k] = (candStats[k] or 0) + v end
                        candStats["STAT_ILVL"] = cand.ilvl or 0
                        local score = self:CalculateScore(candStats, activeRules)
                        if score > bestScore then
                            bestScore = score
                            bestCand = cand
                        end
                    end
                    candidates[slotId] = { bestCand }
                end
            end
        end
    end
    
    self.eqStats = self:GetEquippedStats()
    local currentStats = self:GetPlayerCurrentStats()
    
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
    
    if totalCombinations > 20000 then
        -- Gradual pruning to ensure we don't exceed 20000 combinations
        while totalCombinations > 20000 do
            local maxSlotId = nil
            local maxCount = 2 -- Don't prune below 2 candidates (1 equipped + 1 bag item)
            for _, slotId in ipairs(optimizableSlots) do
                if #candidates[slotId] > maxCount then
                    maxCount = #candidates[slotId]
                    maxSlotId = slotId
                end
            end
            if not maxSlotId then
                break
            end
            table.remove(candidates[maxSlotId])
            -- Recalculate totalCombinations
            totalCombinations = 1
            for _, slotId in ipairs(optimizableSlots) do
                totalCombinations = totalCombinations * #candidates[slotId]
            end
        end
    else
    end
    
    -- Validate that required sets are actually possible with finalized candidates
    local maxPossibleSetCounts = {}
    for slotId, slotCandidates in pairs(candidates) do
        local hasSetID = {}
        for _, cand in ipairs(slotCandidates) do
            if cand.link then
                local setID = tonumber(cand.setID) or cand.setID
                if setID and setID > 0 then
                    hasSetID[setID] = true
                end
            end
        end
        for setID in pairs(hasSetID) do
            maxPossibleSetCounts[setID] = (maxPossibleSetCounts[setID] or 0) + 1
        end
    end

    if profile.requiredSets then
        for reqSetID, reqCount in pairs(profile.requiredSets) do
            local numID = tonumber(reqSetID) or reqSetID
            if reqCount and reqCount > 0 then
                local maxPossible = maxPossibleSetCounts[numID] or 0
                if maxPossible < reqCount then
                    local setName = "Set " .. tostring(numID)
                    local GetItemSetInfo = C_Item and C_Item.GetItemSetInfo or _G.GetItemSetInfo
                    if GetItemSetInfo then
                        local sName = GetItemSetInfo(numID)
                        if sName then setName = sName end
                    end
                    local msg = string.format(L.IMPOSSIBLE_SET_WARN or "Warning: Set requirements for '%s' lowered from %d to %d pieces (not enough matching items in bags/equipped).", setName, reqCount, maxPossible)
                    Core:Print("|cffff3030" .. msg .. "|r")
                    if maxPossible >= 2 then
                        adjustedRequiredSets[numID] = maxPossible
                    end
                else
                    adjustedRequiredSets[numID] = reqCount
                end
            end
        end
    end
    -- Combinations search
    local bestCombination = nil
    local seenPairs = {}
    local totalEvaluated = 0
    local satisfiedSetsCount = 0
    
    local function GenerateCombinations(optIndex, usedBagItems)
        if optIndex > #optimizableSlots then
            totalEvaluated = totalEvaluated + 1
            
            -- Deduplicate swapped combinations of rings and trinkets correctly
            local keys = {}
            for _, slotInfo in ipairs(Core.Slots) do
                local slotId = slotInfo.id
                if slotId ~= 11 and slotId ~= 12 and slotId ~= 13 and slotId ~= 14 then
                    table.insert(keys, currentComb[slotId] and currentComb[slotId].link or "none")
                end
            end
            
            local r1 = currentComb[11] and currentComb[11].link or "none"
            local r2 = currentComb[12] and currentComb[12].link or "none"
            if r1 > r2 then r1, r2 = r2, r1 end
            table.insert(keys, r1)
            table.insert(keys, r2)
            
            local t1 = currentComb[13] and currentComb[13].link or "none"
            local t2 = currentComb[14] and currentComb[14].link or "none"
            if t1 > t2 then t1, t2 = t2, t1 end
            table.insert(keys, t1)
            table.insert(keys, t2)
            
            local pairKey = table.concat(keys, "|")
            if seenPairs[pairKey] then return end
            seenPairs[pairKey] = true
            
            -- Validate: 2H weapon vs OffHand
            local mainHand = currentComb[16]
            local offHand = currentComb[17]
            if mainHand and mainHand.equipType == "INVTYPE_2HWEAPON" then
                -- With 2H weapon, we only evaluate once using the first candidate of slot 17 to avoid duplicates
                if offHand ~= candidates[17][1] then
                    return
                end
            end
            
            -- Validate set requirements
            local setCounts = {}
            for slotId, itemInfo in pairs(currentComb) do
                local actualItem = itemInfo
                local mainHandItem = currentComb[16]
                if slotId == 17 and mainHandItem and mainHandItem.equipType == "INVTYPE_2HWEAPON" then
                    actualItem = nil
                end
                
                if actualItem and actualItem.link then
                    local setID = tonumber(actualItem.setID) or actualItem.setID
                    if setID and setID > 0 then
                        setCounts[setID] = (setCounts[setID] or 0) + 1
                    end
                end
            end
            
            local satisfiesSets = true
            for reqSetID, reqCount in pairs(adjustedRequiredSets) do
                if reqCount and reqCount > 0 then
                    local currentCount = setCounts[reqSetID] or 0
                    if currentCount < reqCount then
                        satisfiesSets = false
                        break
                    end
                end
            end
            
            if not satisfiesSets then
                return
            end
            satisfiedSetsCount = satisfiedSetsCount + 1
            
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
