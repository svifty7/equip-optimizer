-- Comparator.lua for EquipOptimizer
local _, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

-- Calculate total score using stat weights and raw rating caps (pure math, no WoW API)
function ItemEvaluator:CalculateScore(stats, rules)
    local score = 0
    
    local numActive = 0
    for _, rule in ipairs(rules) do
        if rule.enabled then
            numActive = numActive + 1
        end
    end
    
    -- Item level contribution (strictly mathematical)
    score = score + ((stats["STAT_ILVL"] or 0) * 3500)
    
    -- self.activePrimaryStat is determined and stored beforehand (offline/test friendly)
    local primary = self.activePrimaryStat
    if primary then
        local primaryWeight = (numActive + 1.5) * 30
        score = score + ((stats[primary] or 0) * primaryWeight)
    end
    
    local currentIndex = 0
    for _, rule in ipairs(rules) do
        if rule.enabled then
            currentIndex = currentIndex + 1
            local weight = (numActive - currentIndex + 1)
            local val = stats[rule.stat] or 0
            
            if rule.stat == "STAT_ILVL" then
                score = score + (val * weight)
            else
                -- Target soft cap rating (precalculated offline/test friendly)
                local targetRating = rule.targetRating or 0
                if targetRating <= 0 or val <= targetRating then
                    score = score + (val * weight)
                else
                    -- Excess rating above soft cap: multiply by significantly reduced weight (40% weight)
                    score = score + (targetRating * weight) + ((val - targetRating) * (weight * 0.4))
                end
            end
        end
    end
    
    return score
end

-- Compare two combinations using priority rules
function ItemEvaluator:CompareCombinations(combA, combB, rules)
    local scoreA = self:CalculateScore(combA.stats, rules)
    local scoreB = self:CalculateScore(combB.stats, rules)
    
    if scoreA ~= scoreB then
        return scoreA > scoreB
    end
    
    -- Fallback: higher item level wins
    local ilvlA = combA.stats["STAT_ILVL"] or 0
    local ilvlB = combB.stats["STAT_ILVL"] or 0
    return ilvlA > ilvlB
end
