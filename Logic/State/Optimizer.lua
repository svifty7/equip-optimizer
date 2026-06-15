-- Optimizer.lua for EquipOptimizer
local _, addonTable = ...
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local L = addonTable.L

ItemEvaluator.isOptimizing = false
ItemEvaluator.hasOptimizationRun = false
ItemEvaluator.optimizationProgress = 0
ItemEvaluator.analyzedCombinations = 0
ItemEvaluator.lastRecommendations = {}
ItemEvaluator.lastOptimizedStats = {}

local optimizeCoroutine = nil
local asyncFrame = nil

function ItemEvaluator:StopActiveOptimization()
    if self.isOptimizing then
        if asyncFrame then
            asyncFrame:SetScript("OnUpdate", nil)
        end
        optimizeCoroutine = nil
    end
    self.hasOptimizationRun = false
end

function ItemEvaluator:PrepareCandidates(profile)
    self:ClearBagCache()
    local activeRules, ratingPerPercent, bestGemStats = self:GatherActiveRulesAndRatings(profile)
    local candidates = self:ScanEquippedAndBagCandidates(profile, activeRules, bestGemStats)
    candidates = self:PruneNonInteractiveSlots(candidates, activeRules)
    return candidates, activeRules, ratingPerPercent
end

function ItemEvaluator:CalculateTotalCombinations(candidates, optimizableSlots)
    local totalCombinations = 1
    for _, slotId in ipairs(optimizableSlots) do
        totalCombinations = totalCombinations * #candidates[slotId]
    end
    return totalCombinations
end

function ItemEvaluator:CreateOptimizationCoroutine(candidates, currentStats, activeRules, ratingPerPercent, totalCombinations, adjustedRequiredSets)
    local trackedKeys, cleanOffhandDelta = self:PrepareTrackedKeysAndOffhandDelta(activeRules)
    
    local function onProgress(evalCount)
        self.optimizationProgress = math.min(99, math.floor(evalCount / totalCombinations * 100))
        self.analyzedCombinations = evalCount
    end
    
    return coroutine.create(function()
        local best = self:PerformSearch(candidates, currentStats, trackedKeys, activeRules, adjustedRequiredSets, totalCombinations, cleanOffhandDelta, onProgress)
        
        local recs, finalStats = self:BuildOptimizationRecommendations(best, currentStats, ratingPerPercent)
        self.lastRecommendations = recs
        self.lastOptimizedStats = best and finalStats or currentStats
        self.isOptimizing = false
        self.optimizationProgress = 100
        self.hasOptimizationRun = true
    end)
end

function ItemEvaluator:StartUpdateFrame()
    if not asyncFrame then
        asyncFrame = CreateFrame("Frame")
    end
    asyncFrame:SetScript("OnUpdate", function()
        if optimizeCoroutine then
            local status, err = coroutine.resume(optimizeCoroutine)
            if not status then
                self.isOptimizing = false
                self.optimizationProgress = 0
                self.hasOptimizationRun = false
                asyncFrame:SetScript("OnUpdate", nil)
                if err then
                    geterrorhandler()(err)
                end
            elseif coroutine.status(optimizeCoroutine) == "dead" then
                self.isOptimizing = false
                self.optimizationProgress = 100
                self.hasOptimizationRun = true
                asyncFrame:SetScript("OnUpdate", nil)
                local UI = addonTable.UI
                if UI and UI.IsWindowOpen and UI:IsWindowOpen() then
                    UI:Refresh()
                end
            else
                local UI = addonTable.UI
                if UI and UI.IsWindowOpen and UI:IsWindowOpen() and UI.RefreshProgress then
                    UI:RefreshProgress()
                end
            end
        end
    end)
end

-- Perform background search for best items combo
function ItemEvaluator:StartOptimize(force)
    if self.isOptimizing and not force then
        return
    end
    
    self:StopActiveOptimization()
    
    local profile = Core.activeProfile
    local candidates, activeRules, ratingPerPercent = self:PrepareCandidates(profile)
    
    self.eqStats = self:GetEquippedStats()
    local currentStats = self:GetPlayerCurrentStats()
    
    for slotId, eqItem in pairs(self.equipped or {}) do
        if eqItem.potentialGemsStats then
            for k, v in pairs(eqItem.potentialGemsStats) do
                currentStats[k] = (currentStats[k] or 0) + v
            end
        end
    end
    
    local optimizableSlots = self:InitOptimizableSlots(candidates)
    local totalCombinations = self:CalculateTotalCombinations(candidates, optimizableSlots)
    local adjustedRequiredSets = self:GetAdjustedRequiredSets(profile, candidates)
    
    self.isOptimizing = true
    self.optimizationProgress = 0
    self.analyzedCombinations = 0
    
    optimizeCoroutine = self:CreateOptimizationCoroutine(candidates, currentStats, activeRules, ratingPerPercent, totalCombinations, adjustedRequiredSets)
    self:StartUpdateFrame()
end

-- Backward compatibility wrapper for sync/cached Optimize retrieval
function ItemEvaluator:Optimize()
    if not self.hasOptimizationRun and not self.isOptimizing then
        -- Initialize empty defaults
        self.lastRecommendations = {}
        self.lastOptimizedStats = self:GetPlayerCurrentStats()
        self:StartOptimize(true)
    end
    
    return self.lastRecommendations or {}, self.lastOptimizedStats
end

-- Adjust target required set requirements based on max possible counts in candidates pool
function ItemEvaluator:GetAdjustedRequiredSets(profile, candidates)
    local adjustedRequiredSets = {}
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
                    if maxPossible >= 2 then
                        adjustedRequiredSets[numID] = maxPossible
                    end
                else
                    adjustedRequiredSets[numID] = reqCount
                end
            end
        end
    end
    return adjustedRequiredSets
end

-- Construct the final recommendations list & stats comparison delta for the UI
function ItemEvaluator:BuildOptimizationRecommendations(bestCombination, currentStats, ratingPerPercent)
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
                recItem = { link = nil, ilvl = 0, bag = nil, slot = nil }
            end
            
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
    
    local finalStats = {}
    if bestCombination then
        finalStats = self:GetResultingStats(bestCombination.items, currentStats, ratingPerPercent)
    end
    return recommendations, finalStats
end
