-- CapAnalyzer.lua for EquipOptimizer
local _, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator
local Core = addonTable.Core
local L = addonTable.L

local function GetSetName(setID)
    local GetItemSetInfo = C_Item and C_Item.GetItemSetInfo or _G.GetItemSetInfo
    if GetItemSetInfo then
        local setName = GetItemSetInfo(setID)
        if setName then return setName end
    end
    return "Set " .. tostring(setID)
end

local function GetItemStatsString(ratings, suitableStats)
    local parts = {}
    local statKeys = { "STAT_HASTE", "STAT_CRIT", "STAT_MASTERY", "STAT_VERSATILITY" }
    for _, k in ipairs(statKeys) do
        if ratings and ratings[k] and ratings[k] > 0 then
            local name = L[k] or k
            name = name:gsub(" ?%(%%%)", "")
            local ratingStr = string.format("%s %d", name, ratings[k])
            if suitableStats[k] then
                table.insert(parts, string.format("|cff00ff00%s|r", ratingStr))
            else
                table.insert(parts, string.format("|cffff3333%s|r", ratingStr))
            end
        end
    end
    return table.concat(parts, ", ")
end

function ItemEvaluator:GetUnmetCaps(activeRules)
    local unmet = {}
    for _, rule in ipairs(activeRules) do
        local targetRating = rule.value or 0
        local currentRating = self.lastOptimizedStats[rule.stat] or 0
        if targetRating > 0 and currentRating < targetRating then
            local base = self.activeBasePct and self.activeBasePct[rule.stat] or 0
            table.insert(unmet, {
                rule = rule,
                targetRating = targetRating,
                currentRating = currentRating,
                basePercent = base
            })
        end
    end
    return unmet
end

function ItemEvaluator:GetCapsStatus(activeRules)
    local status = {}
    for _, rule in ipairs(activeRules) do
        local targetRating = rule.value or 0
        if targetRating > 0 and targetRating < 999999 then
            local currentRating = self.lastOptimizedStats[rule.stat] or 0
            local base = self.activeBasePct and self.activeBasePct[rule.stat] or 0
            table.insert(status, {
                rule = rule,
                targetRating = targetRating,
                currentRating = currentRating,
                basePercent = base
            })
        end
    end
    return status
end

function ItemEvaluator:IsSlotSetLocked(chosenCand, optimizedSetCounts, adjustedRequiredSets)
    if not chosenCand then return false, nil end
    local setID = chosenCand.setID and (tonumber(chosenCand.setID) or chosenCand.setID)
    if setID and setID > 0 then
        local count = optimizedSetCounts[setID] or 0
        local reqCount = adjustedRequiredSets[setID] or 0
        if reqCount > 0 and count <= reqCount then
            return true, GetSetName(setID)
        end
    end
    return false, nil
end

local function GetItemTotalStat(item, stat)
    if not item then return 0 end
    local ratings = item.ratings or {}
    local gems = item.gemsAndEnchants or {}
    local potential = item.potentialGemsStats or {}
    return (ratings[stat] or 0) + (gems[stat] or 0) + (potential[stat] or 0)
end

function ItemEvaluator:CalculateWeightedHarm(chosenCand, activeRules)
    if not chosenCand or not self.lastOptimizedStats then return 0 end
    local weightedHarm = 0
    for priorityIndex, rule in ipairs(activeRules) do
        local stat = rule.stat
        local targetRating = rule.value or 0
        if targetRating > 0 then
            local currentTotalRating = self.lastOptimizedStats[stat] or 0
            local equippedRating = GetItemTotalStat(chosenCand, stat)
            
            local originalDeficit = math.max(0, targetRating - currentTotalRating)
            local newDeficit = math.max(0, targetRating - (currentTotalRating - equippedRating))
            local harm = newDeficit - originalDeficit
            
            if harm > 0 then
                local weight = 5 - priorityIndex
                if weight < 1 then weight = 1 end
                weightedHarm = weightedHarm + harm * weight
            end
        end
    end
    return weightedHarm
end

function ItemEvaluator:AnalyzeCaps()
    local result = { unmet = {}, slots = {} }
    if not self.lastBestItems or not self.lastCandidates or not self.lastOptimizedStats then
        return result
    end
    
    local secondaryKeys = { STAT_HASTE = true, STAT_CRIT = true, STAT_MASTERY = true, STAT_VERSATILITY = true }
    
    local profile = Core.activeProfile
    local activeRules = {}
    if profile.rules then
        for _, r in ipairs(profile.rules) do
            local targetVal = r.value or 0
            if r.enabled and targetVal > 0 and secondaryKeys[r.stat] then
                table.insert(activeRules, r)
            end
        end
    end
    
    local unmet = self:GetUnmetCaps(activeRules)
    result.unmet = unmet
    result.capsStatus = self:GetCapsStatus(activeRules)
    
    -- Identify suitable stats based on rules
    local suitableStats = {}
    -- The unmet cap stat is always suitable
    for _, item in ipairs(unmet) do
        suitableStats[item.rule.stat] = true
    end
    
    -- The top 2 stats in activeRules are also suitable
    local ruleStats = {}
    if profile.rules then
        for _, r in ipairs(profile.rules) do
            if r.enabled and secondaryKeys[r.stat] then
                table.insert(ruleStats, r.stat)
            end
        end
    end
    for i = 1, math.min(2, #ruleStats) do
        suitableStats[ruleStats[i]] = true
    end
    
    local adjustedRequiredSets = self:GetAdjustedRequiredSets(profile, self.lastCandidates)
    
    -- Pre-calculate optimized set counts
    local optimizedSetCounts = {}
    for slotId, itemInfo in pairs(self.lastBestItems) do
        local mainHand = self.lastBestItems[16]
        local has2H = mainHand and mainHand.equipType == "INVTYPE_2HWEAPON"
        if not (slotId == 17 and has2H) then
            local setID = itemInfo.setID and (tonumber(itemInfo.setID) or itemInfo.setID)
            if setID and setID > 0 then
                optimizedSetCounts[setID] = (optimizedSetCounts[setID] or 0) + 1
            end
        end
    end
    
    local mainHand = self.lastBestItems[16]
    local has2H = mainHand and mainHand.equipType == "INVTYPE_2HWEAPON"
    
    for _, slotInfo in ipairs(Core.Slots) do
        local slotId = slotInfo.id
        if not (slotId == 17 and has2H) then
            local chosenCand = self.lastBestItems[slotId]
            local isLocked = profile.lockedSlots[slotId] and true or false
            local isSetLocked, setName = self:IsSlotSetLocked(chosenCand, optimizedSetCounts, adjustedRequiredSets)
            
            local extraStats = {}
            local extraRatingsTable = {}
            local extraRatingSum = 0
            local ratings = chosenCand and chosenCand.ratings or {}
            for k in pairs(secondaryKeys) do
                if ratings[k] and ratings[k] > 0 and not suitableStats[k] then
                    table.insert(extraStats, k)
                    extraRatingsTable[k] = ratings[k]
                    extraRatingSum = extraRatingSum + ratings[k]
                end
            end
            
            local weightedHarm = 0
            if not isLocked and not isSetLocked then
                weightedHarm = self:CalculateWeightedHarm(chosenCand, activeRules)
            end
            
            table.insert(result.slots, {
                slotId = slotId,
                slotName = L[slotInfo.label] or slotInfo.name,
                itemLink = chosenCand and chosenCand.link or nil,
                isLocked = isLocked,
                isSetLocked = isSetLocked,
                setName = setName,
                extraStats = extraStats,
                extraRatingsTable = extraRatingsTable,
                extraRatingSum = extraRatingSum,
                extraStatsString = GetItemStatsString(ratings, suitableStats),
                tuningScore = extraRatingSum - weightedHarm
            })
        end
    end
    
    return result
end
