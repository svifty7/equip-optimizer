-- TestScoring.lua
-- Offline test simulator to verify the combination sorting and evaluation logic

local ItemEvaluator = {}

-- Mocking stats mapping
local CR_CRIT = 9
local CR_HASTE = 18
local CR_MASTERY = 26
local CR_VERSATILITY = 29
local CR_SPEED = 13
local CR_AVOIDANCE = 14

-- Base rating costs for tertiary stats (strictly linear, no DR)
local TERTIARY_BASE_COSTS = {
    STAT_LEECH = 1100,
    STAT_AVOIDANCE = 1100,
    STAT_SPEED = 1100,
    Leech = 1100,
    Avoidance = 1100,
    Speed = 1100,
}

-- Diminishing returns tiers for secondary stats (percent limit, penalty multiplier)
local DR_TIERS = {
    { limit = 30, penalty = 1.0 },
    { limit = 39, penalty = 0.9 },
    { limit = 47, penalty = 0.8 },
    { limit = 54, penalty = 0.7 },
    { limit = 66, penalty = 0.6 },
    { limit = 78, penalty = 0.5 }
}

-- Get mock base rating cost for secondary stats (fallback to level 90 Midnight values)
function ItemEvaluator:GetBaseRatingCost(statKey, combatRatingID)
    if statKey == "STAT_CRIT" then
        return 1400
    elseif statKey == "STAT_HASTE" then
        return 1320
    elseif statKey == "STAT_MASTERY" then
        return 1400
    elseif statKey == "STAT_VERSATILITY" then
        return 1560
    end
    return 1400 -- fallback
end

-- Convert target percent to target rating with piecewise diminishing returns
function ItemEvaluator:ConvertPercentToRating(statKey, targetPercent)
    if not targetPercent or targetPercent <= 0 then
        return 0
    end
    
    -- Check if it's a tertiary stat
    local tertiaryCost = TERTIARY_BASE_COSTS[statKey]
    if tertiaryCost then
        return targetPercent * tertiaryCost
    end
    
    -- Secondary stats mapping
    local combatRatingID = nil
    if statKey == "STAT_CRIT" then
        combatRatingID = CR_CRIT
    elseif statKey == "STAT_HASTE" then
        combatRatingID = CR_HASTE
    elseif statKey == "STAT_MASTERY" then
        combatRatingID = CR_MASTERY
    elseif statKey == "STAT_VERSATILITY" then
        combatRatingID = CR_VERSATILITY
    end
    
    if not combatRatingID then
        return targetPercent
    end
    
    local baseCost = self:GetBaseRatingCost(statKey, combatRatingID)
    
    -- Piecewise linear diminishing returns calculation
    local remaining = targetPercent
    local totalRating = 0
    local prevLimit = 0
    
    for _, tier in ipairs(DR_TIERS) do
        local tierSize = tier.limit - prevLimit
        if remaining > tierSize then
            totalRating = totalRating + (tierSize * baseCost / tier.penalty)
            remaining = remaining - tierSize
            prevLimit = tier.limit
        else
            totalRating = totalRating + (remaining * baseCost / tier.penalty)
            remaining = 0
            break
        end
    end
    
    if remaining > 0 then
        local lastPenalty = DR_TIERS[#DR_TIERS].penalty
        totalRating = totalRating + (remaining * baseCost / lastPenalty)
    end
    
    return totalRating
end

-- Compare combinations based on priority rules
function ItemEvaluator:CompareCombinations(combA, combB, rules)
    local activeRules = {}
    for _, r in ipairs(rules) do
        if r.enabled == nil or r.enabled == true then
            table.insert(activeRules, r)
        end
    end
    for i, rule in ipairs(activeRules) do
        local valA = combA.stats[rule.stat] or 0
        local valB = combB.stats[rule.stat] or 0
        
        if rule.op == "MAX" then
            if valA ~= valB then
                return valA > valB
            end
        elseif rule.op == "MIN" then
            if valA ~= valB then
                return valA < valB
            end
        else
            local targetRating = self:ConvertPercentToRating(rule.stat, rule.value or 0)
            local satA = false
            local satB = false
            
            if rule.op == ">=" then satA = (valA >= targetRating); satB = (valB >= targetRating)
            elseif rule.op == "<=" then satA = (valA <= targetRating); satB = (valB <= targetRating)
            elseif rule.op == ">" then satA = (valA > targetRating); satB = (valB > targetRating)
            elseif rule.op == "<" then satA = (valA < targetRating); satB = (valB < targetRating)
            elseif rule.op == "=" then
                satA = (math.abs(valA - targetRating) < 50)
                satB = (math.abs(valB - targetRating) < 50)
            end
            
            if satA ~= satB then
                return satA
            elseif not satA then
                -- Neither satisfies, compare who is closer
                if rule.op == ">=" or rule.op == ">" then
                    if valA ~= valB then return valA > valB end
                elseif rule.op == "<=" or rule.op == "<" then
                    if valA ~= valB then return valA < valB end
                else -- "="
                    local distA = math.abs(valA - targetRating)
                    local distB = math.abs(valB - targetRating)
                    if distA ~= distB then return distA < distB end
                end
            end
        end
    end
    
    local ilvlA = combA.stats["STAT_ILVL"] or 0
    local ilvlB = combB.stats["STAT_ILVL"] or 0
    return ilvlA > ilvlB
end

-- Mock implementation of GetResultingStats
function ItemEvaluator:GetResultingStats(combination, currentStats, ratingPerPercent, equipped)
    local netStats = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
        STAT_ILVL = 0,
    }
    
    local has2H = false
    local mainHandItem = combination[16]
    if mainHandItem and mainHandItem.equipType == "INVTYPE_2HWEAPON" then
        has2H = true
    end
    
    for slotId, itemInfo in pairs(combination) do
        local actualItem = itemInfo
        if slotId == 17 and has2H then
            actualItem = { ratings = { STAT_ILVL = mainHandItem.ilvl }, ilvl = mainHandItem.ilvl }
        end
        
        local equippedInfo = equipped[slotId]
        local eqRatings = equippedInfo and equippedInfo.ratings or {}
        local eqGemsEnchants = equippedInfo and equippedInfo.gemsAndEnchants or {}
        local newRatings = actualItem.ratings or {}
        local newGemsEnchants = actualItem.gemsAndEnchants or {}
        
        for k, v in pairs(netStats) do
            local eqVal = (eqRatings[k] or 0) + (eqGemsEnchants[k] or 0)
            local newVal = (newRatings[k] or 0) + (newGemsEnchants[k] or 0)
            netStats[k] = netStats[k] + (newVal - eqVal)
        end
    end
    
    local resulting = {}
    resulting.STAT_CRIT = currentStats.STAT_CRIT + netStats.STAT_CRIT
    resulting.STAT_HASTE = currentStats.STAT_HASTE + netStats.STAT_HASTE
    resulting.STAT_MASTERY = currentStats.STAT_MASTERY + netStats.STAT_MASTERY
    resulting.STAT_VERSATILITY = currentStats.STAT_VERSATILITY + netStats.STAT_VERSATILITY
    resulting.STAT_LEECH = currentStats.STAT_LEECH + netStats.STAT_LEECH
    resulting.STAT_AVOIDANCE = currentStats.STAT_AVOIDANCE + netStats.STAT_AVOIDANCE
    resulting.STAT_SPEED = currentStats.STAT_SPEED + netStats.STAT_SPEED
    resulting.STAT_ILVL = currentStats.STAT_ILVL + (netStats.STAT_ILVL / 16)
    
    return resulting
end

-- TEST RUNNER
local function RunTests()
    print("Starting optimization algorithm simulation tests...\n")
    
    -- Current player stats (stored in raw ratings)
    -- Haste: 22% -> 22 * 1320 = 29040 rating
    -- Crit: 15% -> 15 * 1400 = 21000 rating
    -- Mastery: 18% -> 18 * 1400 = 25200 rating
    -- Versatility: 5% -> 5 * 1560 = 7800 rating
    local currentStats = {
        STAT_CRIT = 21000,
        STAT_HASTE = 29040,
        STAT_MASTERY = 25200,
        STAT_VERSATILITY = 7800,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
        STAT_ILVL = 600.0,
    }
    
    -- Level 90 rating conversions
    local ratingPerPercent = {
        STAT_CRIT = 1400,
        STAT_HASTE = 1320,
        STAT_MASTERY = 1400,
        STAT_VERSATILITY = 1560,
    }
    
    -- Player rules (Priority order)
    -- 1. Haste >= 25% (converts to 33000 rating)
    -- 2. Mastery >= 20% (converts to 28000 rating)
    -- 3. Maximize Crit
    local rules = {
        { stat = "STAT_HASTE", enabled = true, op = ">=", value = 25.0 },
        { stat = "STAT_MASTERY", enabled = true, op = ">=", value = 20.0 },
        { stat = "STAT_CRIT", enabled = true, op = "MAX", value = 0 },
    }
    
    -- Mock equipped items (slots 11, 12: Rings)
    local equipped = {
        [11] = { link = "Equipped Ring 1", ratings = { STAT_HASTE = 300, STAT_CRIT = 100 }, gemsAndEnchants = { STAT_HASTE = 50 }, ilvl = 600 },
        [12] = { link = "Equipped Ring 2", ratings = { STAT_MASTERY = 400, STAT_VERSATILITY = 100 }, gemsAndEnchants = {}, ilvl = 600 }
    }
    
    -- Mock candidates for Ring slots
    local candidates = {
        [11] = {
            equipped[11], -- Equipped Ring 1
            -- Bag Ring A provides Haste = 4300 rating (which is > 3960 net needed to reach 33000)
            { link = "Bag Ring A", ratings = { STAT_HASTE = 4300, STAT_CRIT = 50 }, gemsAndEnchants = { STAT_HASTE = 100 }, ilvl = 610, bag = 0, slot = 1 },
            { link = "Bag Ring B", ratings = { STAT_MASTERY = 600, STAT_CRIT = 200 }, gemsAndEnchants = {}, ilvl = 615, bag = 0, slot = 2 }
        },
        [12] = {
            equipped[12], -- Equipped Ring 2
            -- Bag Ring C provides Mastery = 3200 rating (which is > 2800 net needed to reach 28000)
            { link = "Bag Ring C", ratings = { STAT_HASTE = 200, STAT_MASTERY = 3200 }, gemsAndEnchants = {}, ilvl = 610, bag = 0, slot = 3 }
        }
    }
    
    -- Run combination search over optimizable slots 11 and 12
    local bestCombination = nil
    local currentComb = {}
    
    local function Generate(optIndex, usedBagItems)
        if optIndex > 2 then
            local comb = {}
            for k, v in pairs(currentComb) do comb[k] = v end
            
            local stats = ItemEvaluator:GetResultingStats(comb, currentStats, ratingPerPercent, equipped)
            local node = { items = comb, stats = stats }
            
            if not bestCombination then
                bestCombination = node
            else
                if ItemEvaluator:CompareCombinations(node, bestCombination, rules) then
                    bestCombination = node
                end
            end
            return
        end
        
        local slotId = (optIndex == 1) and 11 or 12
        local slotCandidates = candidates[slotId]
        
        for _, cand in ipairs(slotCandidates) do
            local key = cand.bag and string.format("%d-%d", cand.bag, cand.slot) or nil
            if not key or not usedBagItems[key] then
                if key then usedBagItems[key] = true end
                currentComb[slotId] = cand
                
                Generate(optIndex + 1, usedBagItems)
                
                currentComb[slotId] = nil
                if key then usedBagItems[key] = nil end
            end
        end
    end
    
    Generate(1, {})
    
    -- Output results
    assert(bestCombination ~= nil, "Should find at least one combination")
    
    local function GetPct(statKey, ratingVal)
        local base = ratingPerPercent[statKey] or 1000
        return ratingVal / base
    end
    
    print("Optimization results:")
    print("Equipped items stats:")
    print(string.format("  Haste: %.2f%%, Mastery: %.2f%%, Crit: %.2f%%", GetPct("STAT_HASTE", currentStats.STAT_HASTE), GetPct("STAT_MASTERY", currentStats.STAT_MASTERY), GetPct("STAT_CRIT", currentStats.STAT_CRIT)))
    
    print("\nBest Combination chosen:")
    print("  Slot 11 ring: " .. bestCombination.items[11].link)
    print("  Slot 12 ring: " .. bestCombination.items[12].link)
    
    print("\nNew Stats:")
    print(string.format("  Haste: %.2f%% (Goal >= 25%%)", GetPct("STAT_HASTE", bestCombination.stats.STAT_HASTE)))
    print(string.format("  Mastery: %.2f%% (Goal >= 20%%)", GetPct("STAT_MASTERY", bestCombination.stats.STAT_MASTERY)))
    print(string.format("  Crit: %.2f%% (Goal Maximize)", GetPct("STAT_CRIT", bestCombination.stats.STAT_CRIT)))
    print(string.format("  Item Level: %.1f", bestCombination.stats.STAT_ILVL))
    
    -- Verify Haste goal was satisfied first if possible
    local targetHasteRating = ItemEvaluator:ConvertPercentToRating("STAT_HASTE", 25.0)
    assert(bestCombination.stats.STAT_HASTE >= targetHasteRating, "Haste goal should be satisfied since Bag Ring A provides enough haste rating")
    
    -- Verify Mastery goal was satisfied as well
    local targetMasteryRating = ItemEvaluator:ConvertPercentToRating("STAT_MASTERY", 20.0)
    assert(bestCombination.stats.STAT_MASTERY >= targetMasteryRating, "Mastery goal should be satisfied since Bag Ring C provides enough mastery rating")
    
    print("\nSUCCESS: Optimization logic successfully satisfied prioritized targets!")
end

RunTests()
