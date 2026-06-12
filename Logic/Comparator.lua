-- Comparator.lua for EquipOptimizer
local addonName, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

-- Compare two combinations using priority rules
function ItemEvaluator:CompareCombinations(combA, combB, rules)
    for _, rule in ipairs(rules) do
        local valA = combA.stats[rule.stat] or 0
        local valB = combB.stats[rule.stat] or 0
        
        if rule.op == "MAX" then
            if valA ~= valB then
                return valA > valB
            end
        else -- rule.op == ">="
            local targetRating = self:ConvertPercentToRating(rule.stat, rule.value or 0)
            local satA = (valA >= targetRating)
            local satB = (valB >= targetRating)
            
            if satA ~= satB then
                return satA
            elseif not satA then
                -- Neither satisfies, compare who is closer (higher value is closer to target)
                if valA ~= valB then
                    return valA > valB
                end
            end
        end
    end
    -- Fallback: higher item level wins
    local ilvlA = combA.stats["STAT_ILVL"] or 0
    local ilvlB = combB.stats["STAT_ILVL"] or 0
    return ilvlA > ilvlB
end
