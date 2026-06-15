-- SearchEngineHelper.lua for EquipOptimizer
local _, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator
local Core = addonTable.Core

-- Initialize optimizable slots and current combination
function ItemEvaluator:InitOptimizableSlots(candidatesPool)
    local poolOptimizableSlots = {}
    local poolCurrentComb = {}
    for slotId, slotCandidates in pairs(candidatesPool) do
        if #slotCandidates == 1 then
            poolCurrentComb[slotId] = slotCandidates[1]
        else
            table.insert(poolOptimizableSlots, slotId)
        end
    end
    return poolOptimizableSlots, poolCurrentComb
end

-- Precalculate stat deltas for candidates relative to equipped
function ItemEvaluator:CalcStatDeltas(candidatesPool, trackedKeys)
    for slotId, slotCandidates in pairs(candidatesPool) do
        local eqItem = self.equipped[slotId]
        for _, cand in ipairs(slotCandidates) do
            cand.statDeltas = cand.statDeltas or {}
            cand.statDeltas[slotId] = {}
            local slotDeltas = cand.statDeltas[slotId]
            local eqRatings = eqItem and eqItem.ratings or {}
            local eqGemsEnchants = eqItem and eqItem.gemsAndEnchants or {}
            local eqPotential = eqItem and eqItem.potentialGemsStats or {}
            local newRatings = cand.ratings or {}
            local newGemsEnchants = cand.gemsAndEnchants or {}
            local newPotential = cand.potentialGemsStats or {}
            
            for _, k in ipairs(trackedKeys) do
                if k ~= "STAT_ILVL" then
                    local eqVal = (eqRatings[k] or 0) + (eqGemsEnchants[k] or 0) + (eqPotential[k] or 0)
                    local newVal = (newRatings[k] or 0) + (newGemsEnchants[k] or 0) + (newPotential[k] or 0)
                    local delta = newVal - eqVal
                    if delta ~= 0 then
                        slotDeltas[k] = delta
                    end
                end
            end
            local eqIlvl = eqItem and eqItem.ilvl or 0
            local newIlvl = cand.ilvl or 0
            if newIlvl ~= eqIlvl then
                slotDeltas["STAT_ILVL"] = (newIlvl - eqIlvl) / 16
            end
        end
    end
end


-- Precalculate slotHasSet and suffixMaxSet
function ItemEvaluator:CalcSetsPruning(poolOptimizableSlots, candidatesPool, adjustedRequiredSets)
    local slotHasSet = {}
    for slotId, slotCandidates in pairs(candidatesPool) do
        slotHasSet[slotId] = {}
        for _, cand in ipairs(slotCandidates) do
            local setID = cand.setID and (tonumber(cand.setID) or cand.setID)
            if setID and setID > 0 then
                slotHasSet[slotId][setID] = true
            end
        end
    end
    
    local suffixMaxSet = {}
    for i = 1, #poolOptimizableSlots + 1 do
        suffixMaxSet[i] = {}
    end
    for reqSetID in pairs(adjustedRequiredSets) do
        suffixMaxSet[#poolOptimizableSlots + 1][reqSetID] = 0
        for i = #poolOptimizableSlots, 1, -1 do
            local slotId = poolOptimizableSlots[i]
            local has = slotHasSet[slotId][reqSetID] and 1 or 0
            suffixMaxSet[i][reqSetID] = suffixMaxSet[i+1][reqSetID] + has
        end
    end
    return suffixMaxSet
end

-- Initialize runningStats
function ItemEvaluator:InitRunningStats(poolCurrentComb, trackedKeys, currentStats)
    local runningStats = {}
    for _, k in ipairs(trackedKeys) do
        runningStats[k] = currentStats[k] or 0
    end
    -- Add deltas of fixed slots
    for slotId, cand in pairs(poolCurrentComb) do
        local deltas = cand.statDeltas and cand.statDeltas[slotId]
        for k, delta in pairs(deltas or {}) do
            runningStats[k] = runningStats[k] + delta
        end
    end
    return runningStats
end

-- Initialize runningSetCounts
function ItemEvaluator:InitRunningSetCounts(poolCurrentComb, adjustedRequiredSets)
    local runningSetCounts = {}
    for reqSetID in pairs(adjustedRequiredSets) do
        runningSetCounts[reqSetID] = 0
    end
    for slotId, cand in pairs(poolCurrentComb) do
        local mainHandItem = poolCurrentComb[16]
        if not (slotId == 17 and mainHandItem and mainHandItem.equipType == "INVTYPE_2HWEAPON") then
            local setID = cand.setID and (tonumber(cand.setID) or cand.setID)
            if setID and runningSetCounts[setID] then
                runningSetCounts[setID] = runningSetCounts[setID] + 1
            end
        end
    end
    return runningSetCounts
end

-- Handle FPS-based budget scaling and coroutine yield
function ItemEvaluator:HandleSearchYield(totalEvaluated, iterationsPerBatch, lastYieldTime, onProgress)
    local now = debugprofilestop()
    local elapsed = now - lastYieldTime
    
    local fps = GetFramerate()
    local frameBudget = 8
    if fps and fps > 0 then
        if fps > 80 then
            frameBudget = 10
        elseif fps < 30 then
            frameBudget = 4
        else
            frameBudget = 6
        end
    end
    
    if elapsed > frameBudget then
        if onProgress then
            onProgress(totalEvaluated)
        end
        coroutine.yield()
        
        local targetIterations = math.floor(iterationsPerBatch * (frameBudget / elapsed))
        iterationsPerBatch = math.max(100, math.min(10000, targetIterations))
        lastYieldTime = debugprofilestop()
    end
    return iterationsPerBatch, lastYieldTime
end

-- Evaluate leaf node combination in DFS
function ItemEvaluator:VerifyRequiredSets(poolCurrentComb, adjustedRequiredSets, has2H)
    self.setCounts = self.setCounts or {}
    table.wipe(self.setCounts)
    local setCounts = self.setCounts
    
    for slotId, itemInfo in pairs(poolCurrentComb) do
        local actualItem = (slotId == 17 and has2H) and nil or itemInfo
        if actualItem and actualItem.link then
            local setID = tonumber(actualItem.setID) or actualItem.setID
            if setID and setID > 0 then
                setCounts[setID] = (setCounts[setID] or 0) + 1
            end
        end
    end
    
    for reqSetID, reqCount in pairs(adjustedRequiredSets) do
        if reqCount and reqCount > 0 and (setCounts[reqSetID] or 0) < reqCount then
            return false
        end
    end
    return true
end

-- Evaluate leaf node combination in DFS
function ItemEvaluator:EvaluateLeaf(poolCurrentComb, candidatesPool, adjustedRequiredSets, trackedKeys, runningStats, activeRules, poolBestCombination, seenPairs)
    local mainHand = poolCurrentComb[16]
    if mainHand and mainHand.equipType == "INVTYPE_2HWEAPON" and poolCurrentComb[17] ~= candidatesPool[17][1] then
        return poolBestCombination
    end
    
    local has2H = mainHand and mainHand.equipType == "INVTYPE_2HWEAPON"
    if not self:VerifyRequiredSets(poolCurrentComb, adjustedRequiredSets, has2H) then
        return poolBestCombination
    end
    
    -- Deduplicate swapped combinations of rings and trinkets correctly
    local keys = {}
    for _, slotInfo in ipairs(Core.Slots) do
        local slotId = slotInfo.id
        if slotId ~= 11 and slotId ~= 12 and slotId ~= 13 and slotId ~= 14 then
            table.insert(keys, poolCurrentComb[slotId] and poolCurrentComb[slotId].link or "none")
        end
    end
    
    local r1 = poolCurrentComb[11] and poolCurrentComb[11].link or "none"
    local r2 = poolCurrentComb[12] and poolCurrentComb[12].link or "none"
    if r1 > r2 then r1, r2 = r2, r1 end
    table.insert(keys, r1)
    table.insert(keys, r2)
    
    local t1 = poolCurrentComb[13] and poolCurrentComb[13].link or "none"
    local t2 = poolCurrentComb[14] and poolCurrentComb[14].link or "none"
    if t1 > t2 then t1, t2 = t2, t1 end
    table.insert(keys, t1)
    table.insert(keys, t2)
    
    local pairKey = table.concat(keys, "|")
    if seenPairs[pairKey] then return poolBestCombination end
    seenPairs[pairKey] = true
    
    local score = self:CalculateScore(runningStats, activeRules)
    if not poolBestCombination or score > poolBestCombination.score then
        local combNode = { items = {}, stats = {}, score = score }
        for k, v in pairs(poolCurrentComb) do
            combNode.items[k] = v
        end
        for _, k in ipairs(trackedKeys) do
            combNode.stats[k] = runningStats[k]
        end
        return combNode
    end
    return poolBestCombination
end
