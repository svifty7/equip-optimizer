-- TestScoring.lua
-- Offline test simulator to verify the combination sorting and evaluation logic

local ItemEvaluator = {}

-- Load helper functions to populate ItemEvaluator mock methods
local loadHelper = dofile("TestScoringHelper.lua")
loadHelper(ItemEvaluator)

-- TEST RUNNER
local function RunTests()
    print("Starting optimization algorithm simulation tests...\n")
    
    local mockData = dofile("TestScoringMockData.lua")
    local currentStats = mockData.currentStats
    local ratingPerPercent = mockData.ratingPerPercent
    local rules = mockData.rules
    local equipped = mockData.equipped
    local candidates = mockData.candidates
    
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
        return ItemEvaluator:ConvertRatingToPercent(statKey, ratingVal)
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
