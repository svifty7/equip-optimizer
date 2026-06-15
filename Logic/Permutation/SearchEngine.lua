-- SearchEngine.lua for EquipOptimizer
local _, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

-- Run Branch & Bound DFS search over candidates pool
function ItemEvaluator:CheckPruning(optIndex, state)
    for reqSetID, reqCount in pairs(state.adjustedRequiredSets) do
        if (state.runningSetCounts[reqSetID] or 0) + (state.suffixMaxSet[optIndex][reqSetID] or 0) < reqCount then
            return true
        end
    end
    
    if state.poolBestCombination then
        for _, k in ipairs(state.trackedKeys) do
            state.upperBoundStats[k] = state.runningStats[k] + (state.suffixMaxDelta[optIndex][k] or 0)
        end
        local ubScore = self:CalculateScore(state.upperBoundStats, state.activeRules)
        if ubScore <= state.poolBestCombination.score then
            return true
        end
    end
    return false
end

function ItemEvaluator:ApplyCandidateDelta(slotId, cand, state, is2H)
    if is2H then
        for k, v in pairs(cand.statDeltas or {}) do
            state.runningStats[k] = state.runningStats[k] + v
        end
        for k, v in pairs(state.cleanOffhandDelta) do
            state.runningStats[k] = state.runningStats[k] + v
        end
        state.runningStats["STAT_ILVL"] = state.runningStats["STAT_ILVL"] + cand.ilvl / 16
    else
        for k, v in pairs(cand.statDeltas or {}) do
            state.runningStats[k] = state.runningStats[k] + v
        end
    end
end

function ItemEvaluator:BacktrackCandidateDelta(slotId, cand, state, is2H)
    if is2H then
        for k, v in pairs(cand.statDeltas or {}) do
            state.runningStats[k] = state.runningStats[k] - v
        end
        for k, v in pairs(state.cleanOffhandDelta) do
            state.runningStats[k] = state.runningStats[k] - v
        end
        state.runningStats["STAT_ILVL"] = state.runningStats["STAT_ILVL"] - cand.ilvl / 16
    else
        for k, v in pairs(cand.statDeltas or {}) do
            state.runningStats[k] = state.runningStats[k] - v
        end
    end
end

function ItemEvaluator:ApplyCandidateSets(slotId, cand, state, is2H)
    local setID = cand.setID and (tonumber(cand.setID) or cand.setID)
    local setAdjusted = false
    if is2H then
        local eq17 = self.equipped[17]
        local eq17SetID = eq17 and eq17.setID and (tonumber(eq17.setID) or eq17.setID)
        if eq17SetID and state.runningSetCounts[eq17SetID] then
            state.runningSetCounts[eq17SetID] = state.runningSetCounts[eq17SetID] - 1
            setAdjusted = true
        end
    end
    
    local setAdded = false
    if setID and state.runningSetCounts[setID] then
        state.runningSetCounts[setID] = state.runningSetCounts[setID] + 1
        setAdded = true
    end
    return setID, setAdded, setAdjusted
end

function ItemEvaluator:BacktrackCandidateSets(state, setID, setAdded, setAdjusted)
    if setAdded then
        state.runningSetCounts[setID] = state.runningSetCounts[setID] - 1
    end
    if setAdjusted then
        local eq17 = self.equipped[17]
        local eq17SetID = eq17 and eq17.setID and (tonumber(eq17.setID) or eq17.setID)
        if eq17SetID and state.runningSetCounts[eq17SetID] then
            state.runningSetCounts[eq17SetID] = state.runningSetCounts[eq17SetID] + 1
        end
    end
end

function ItemEvaluator:SearchStep(optIndex, state)
    state.totalEvaluated = state.totalEvaluated + 1
    if state.totalEvaluated % state.iterationsPerBatch == 0 then
        state.iterationsPerBatch, state.lastYieldTime = self:HandleSearchYield(state.totalEvaluated, state.iterationsPerBatch, state.lastYieldTime, state.onProgress)
    end
    
    if self:CheckPruning(optIndex, state) then return end
    
    if optIndex > #state.poolOptimizableSlots then
        state.poolBestCombination = self:EvaluateLeaf(
            state.poolCurrentComb,
            state.candidatesPool,
            state.adjustedRequiredSets,
            state.trackedKeys,
            state.runningStats,
            state.activeRules,
            state.poolBestCombination
        )
        return
    end
    
    local slotId = state.poolOptimizableSlots[optIndex]
    local slotCandidates = state.candidatesPool[slotId]
    
    for _, cand in ipairs(slotCandidates) do
        local key = cand.searchKey
        local isDuplicate = false
        if slotId == 12 then
            local r1 = state.poolCurrentComb[11]
            if r1 and r1.searchKey and key then
                local swapsA = (r1.searchKey ~= "eq-11" and 1 or 0) + (key ~= "eq-12" and 1 or 0)
                local swapsB = (key ~= "eq-11" and 1 or 0) + (r1.searchKey ~= "eq-12" and 1 or 0)
                if swapsA > swapsB then
                    isDuplicate = true
                elseif swapsA == swapsB and key <= r1.searchKey then
                    isDuplicate = true
                end
            end
        elseif slotId == 14 then
            local t1 = state.poolCurrentComb[13]
            if t1 and t1.searchKey and key then
                local swapsA = (t1.searchKey ~= "eq-13" and 1 or 0) + (key ~= "eq-14" and 1 or 0)
                local swapsB = (key ~= "eq-13" and 1 or 0) + (t1.searchKey ~= "eq-14" and 1 or 0)
                if swapsA > swapsB then
                    isDuplicate = true
                elseif swapsA == swapsB and key <= t1.searchKey then
                    isDuplicate = true
                end
            end
        end
        
        if not isDuplicate and (not key or not state.usedBagItems[key]) then
            if key then state.usedBagItems[key] = true end
            state.poolCurrentComb[slotId] = cand
            
            local is2H = (slotId == 16 and cand.equipType == "INVTYPE_2HWEAPON")
            self:ApplyCandidateDelta(slotId, cand, state, is2H)
            local setID, setAdded, setAdjusted = self:ApplyCandidateSets(slotId, cand, state, is2H)
            
            self:SearchStep(optIndex + 1, state)
            
            self:BacktrackCandidateSets(state, setID, setAdded, setAdjusted)
            self:BacktrackCandidateDelta(slotId, cand, state, is2H)
            
            state.poolCurrentComb[slotId] = nil
            if key then state.usedBagItems[key] = nil end
        end
    end
end

-- Run Branch & Bound DFS search over candidates pool
function ItemEvaluator:PerformSearch(candidatesPool, currentStats, trackedKeys, activeRules, adjustedRequiredSets, totalCombinations, cleanOffhandDelta, onProgress, initialBest)
    local poolOptimizableSlots, poolCurrentComb = self:InitOptimizableSlots(candidatesPool)
    self:CalcStatDeltas(candidatesPool, trackedKeys)
    
    local suffixMaxDelta = self:CalcBounds(poolOptimizableSlots, candidatesPool, trackedKeys)
    local suffixMaxSet = self:CalcSetsPruning(poolOptimizableSlots, candidatesPool, adjustedRequiredSets)
    local runningStats = self:InitRunningStats(poolCurrentComb, trackedKeys, currentStats)
    local runningSetCounts = self:InitRunningSetCounts(poolCurrentComb, adjustedRequiredSets)
    
    self.upperBoundStats = self.upperBoundStats or {}
    table.wipe(self.upperBoundStats)
    
    self.usedBagItems = self.usedBagItems or {}
    table.wipe(self.usedBagItems)
    for slotId, cand in pairs(poolCurrentComb) do
        if cand.searchKey then
            self.usedBagItems[cand.searchKey] = true
        end
    end
    
    local state = {
        poolOptimizableSlots = poolOptimizableSlots,
        poolCurrentComb = poolCurrentComb,
        candidatesPool = candidatesPool,
        adjustedRequiredSets = adjustedRequiredSets,
        trackedKeys = trackedKeys,
        runningStats = runningStats,
        runningSetCounts = runningSetCounts,
        activeRules = activeRules,
        cleanOffhandDelta = cleanOffhandDelta,
        suffixMaxDelta = suffixMaxDelta,
        suffixMaxSet = suffixMaxSet,
        upperBoundStats = self.upperBoundStats,
        usedBagItems = self.usedBagItems,
        iterationsPerBatch = 500,
        lastYieldTime = debugprofilestop(),
        totalEvaluated = 0,
        poolBestCombination = initialBest,
        onProgress = onProgress,
    }
    
    self:SearchStep(1, state)
    
    if onProgress then
        onProgress(state.totalEvaluated)
    end
    
    return state.poolBestCombination
end

-- Check if a combination satisfies all rules and required sets
function ItemEvaluator:CheckIfSatisfiesAll(combination, stats, activeRules, adjustedRequiredSets)
    if adjustedRequiredSets and next(adjustedRequiredSets) then
        local setCounts = {}
        local has2H = false
        local mainHandItem = combination[16]
        if mainHandItem and mainHandItem.equipType == "INVTYPE_2HWEAPON" then
            has2H = true
        end
        
        for slotId, itemInfo in pairs(combination) do
            local actualItem = itemInfo
            if slotId == 17 and has2H then
                actualItem = nil
            end
            if actualItem and actualItem.link then
                local setID = tonumber(actualItem.setID) or actualItem.setID
                if setID and setID > 0 then
                    setCounts[setID] = (setCounts[setID] or 0) + 1
                end
            end
        end
        for reqSetID, reqCount in pairs(adjustedRequiredSets) do
            if reqCount and reqCount > 0 then
                local count = setCounts[reqSetID] or 0
                if count < reqCount then
                    return false
                end
            end
        end
    end
    
    for _, rule in ipairs(activeRules) do
        if rule.enabled and rule.op == ">=" then
            local val = stats[rule.stat] or 0
            local targetRating = self:ConvertPercentToRating(rule.stat, rule.value or 0)
            if val < targetRating then
                return false
            end
        end
    end
    return true
end
