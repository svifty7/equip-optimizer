-- OptimizerSetup.lua for EquipOptimizer
local _, addonTable = ...
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator

-- Gather active rules and compute target combat ratings
function ItemEvaluator:GatherActiveRulesAndRatings(profile)
    local activeRules = {}
    if profile.rules then
        for _, r in ipairs(profile.rules) do
            if r.enabled then
                r.targetRating = r.value or 0
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
    return activeRules, ratingPerPercent, bestGemStats
end
function ItemEvaluator:PopulatePotentialGemsStats(item, bestGemStats)
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
function ItemEvaluator:GetEquippedItemForScan(slotId, bestGemStats)
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
        
        local totalRating = 0
        for _, val in pairs(ratings) do
            totalRating = totalRating + val
        end
        
        eqItem = {
            link = itemLink,
            searchKey = string.format("eq-%d", slotId),
            ratings = ratings,
            gemsAndEnchants = gemsAndEnchants,
            ilvl = ilvl,
            equipType = equipType,
            isEquipped = true,
            slotId = slotId,
            setID = setID,
            totalRating = totalRating
        }
    else
        eqItem = { ratings = {}, gemsAndEnchants = {}, ilvl = 0, link = nil, isEquipped = true, slotId = slotId, potentialGemsStats = {}, searchKey = string.format("eq-%d", slotId), totalRating = 0 }
    end
    self:PopulatePotentialGemsStats(eqItem, bestGemStats)
    return eqItem
end

function ItemEvaluator:PopulateLockedSlotCandidates(slotId, eqItem, lockVal, bestGemStats, slotCandidates)
    if lockVal == true or lockVal == "equipped" then
        table.insert(slotCandidates, eqItem)
    else
        local bagItems = self:GetBagItemsForSlot(slotId)
        for _, item in ipairs(bagItems) do
            self:PopulatePotentialGemsStats(item, bestGemStats)
        end
        for _, item in ipairs(bagItems) do
            if item.link == lockVal then
                table.insert(slotCandidates, item)
                return
            end
        end
        local equippedItems = self:GetEquippedItemsForSlot(slotId)
        for _, item in ipairs(equippedItems) do
            self:PopulatePotentialGemsStats(item, bestGemStats)
        end
        for _, item in ipairs(equippedItems) do
            if item.link == lockVal then
                table.insert(slotCandidates, item)
                return
            end
        end
        table.insert(slotCandidates, eqItem)
    end
end

function ItemEvaluator:PopulateBagCandidatesForSlot(slotId, eqItem, profile, activeRules, bestGemStats, slotCandidates)
    local lockVal = profile.lockedSlots[slotId]
    if not lockVal then
        local bagItems = self:GetBagItemsForSlot(slotId)
        for _, item in ipairs(bagItems) do
            self:PopulatePotentialGemsStats(item, bestGemStats)
        end
        
        table.sort(bagItems, function(a, b)
            if a.ilvl ~= b.ilvl then
                return a.ilvl > b.ilvl
            end
            for _, rule in ipairs(activeRules) do
                local valA = a.ratings[rule.stat] or 0
                local valB = b.ratings[rule.stat] or 0
                if valA ~= valB then
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
                table.insert(slotCandidates, item)
                count = count + 1
                if count >= limit then break end
            end
        end
    else
        self:PopulateLockedSlotCandidates(slotId, eqItem, lockVal, bestGemStats, slotCandidates)
    end
end


-- Scan player equipped and bag items to construct potential candidates pool
function ItemEvaluator:ScanEquippedAndBagCandidates(profile, activeRules, bestGemStats)
    self.equipped = {}
    local candidates = {}
    
    for _, slotInfo in ipairs(Core.Slots) do
        local slotId = slotInfo.id
        candidates[slotId] = {}
        
        local eqItem = self:GetEquippedItemForScan(slotId, bestGemStats)
        self.equipped[slotId] = eqItem
        
        if slotId == 17 then
            local mainHand = self.equipped[16]
            if mainHand and mainHand.equipType == "INVTYPE_2HWEAPON" then
                eqItem.ratings.STAT_ILVL = mainHand.ilvl
                eqItem.ilvl = mainHand.ilvl
            end
        end
        
        table.insert(candidates[slotId], eqItem)
        self:PopulateBagCandidatesForSlot(slotId, eqItem, profile, activeRules, bestGemStats, candidates[slotId])
    end
    
    
    return candidates
end

-- Filter slot candidates if they don't impact any active constraints
function ItemEvaluator:PruneNonInteractiveSlots(candidates, activeRules)
    local hasInteractions = false
    for _, rule in ipairs(activeRules) do
        local targetVal = rule.value or 0
        if targetVal > 0 then
            hasInteractions = true
            break
        end
    end
    
    local profile = Core.activeProfile
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
    return candidates
end

-- Filter and prepare stats tracked in optimizer + calc delta for offhand slot
function ItemEvaluator:PrepareTrackedKeysAndOffhandDelta(activeRules)
    local trackedStats = {}
    trackedStats["STAT_ILVL"] = true
    local primary = self.GetActivePrimaryStat and self:GetActivePrimaryStat()
    if primary then
        trackedStats[primary] = true
    end
    for _, rule in ipairs(activeRules) do
        trackedStats[rule.stat] = true
    end
    local trackedKeys = {}
    for k in pairs(trackedStats) do
        table.insert(trackedKeys, k)
    end
    
    local eq17 = self.equipped[17]
    local cleanOffhandDelta = {}
    if eq17 then
        local eqRatings = eq17.ratings or {}
        local eqGemsEnchants = eq17.gemsAndEnchants or {}
        local eqPotential = eq17.potentialGemsStats or {}
        for _, k in ipairs(trackedKeys) do
            if k ~= "STAT_ILVL" then
                local eqVal = (eqRatings[k] or 0) + (eqGemsEnchants[k] or 0) + (eqPotential[k] or 0)
                if eqVal ~= 0 then
                    cleanOffhandDelta[k] = -eqVal
                end
            end
        end
        local eq17Ilvl = eq17.ratings and eq17.ratings.STAT_ILVL or eq17.ilvl or 0
        if eq17Ilvl ~= 0 then
            cleanOffhandDelta["STAT_ILVL"] = -eq17Ilvl / 16
        end
    end
    return trackedKeys, cleanOffhandDelta
end
