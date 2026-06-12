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
    -- Fallback: higher item level wins
    local ilvlA = combA.stats["STAT_ILVL"] or 0
    local ilvlB = combB.stats["STAT_ILVL"] or 0
    return ilvlA > ilvlB
end
