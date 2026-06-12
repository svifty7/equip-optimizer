-- Comparator.lua for EquipOptimizer
local _, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

-- Calculate total score using stat weights
function ItemEvaluator:CalculateScore(stats, rules)
    local score = 0
    
    local numActive = 0
    for _, rule in ipairs(rules) do
        if rule.enabled then
            numActive = numActive + 1
        end
    end
    
    local primaryWeight = (numActive + 1.5) * 30
    local primary = self.GetActivePrimaryStat and self:GetActivePrimaryStat()
    if primary then
        score = score + ((stats[primary] or 0) * primaryWeight)
    end
    
    score = score + ((stats["STAT_ILVL"] or 0) * 3500)
    
    local currentIndex = 0
    for _, rule in ipairs(rules) do
        if rule.enabled then
            currentIndex = currentIndex + 1
            local weight = (numActive - currentIndex + 1)
            local val = stats[rule.stat] or 0
            
            if rule.op == "MAX" then
                score = score + (val * weight)
            else -- rule.op == ">="
                local targetRating = self:ConvertPercentToRating(rule.stat, rule.value or 0)
                if val <= targetRating then
                    -- High value while below cap
                    score = score + (val * weight)
                else
                    -- After cap, give it a moderately diminished weight (40%) instead of crippling it
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
