-- TestScoringHelper.lua
-- Contains the mock methods for testing offline

table.wipe = table.wipe or function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

local CR_CRIT = 9
local CR_HASTE = 18
local CR_MASTERY = 26
local CR_VERSATILITY = 29
local CR_SPEED = 13
local CR_AVOIDANCE = 14

local TERTIARY_BASE_COSTS = {
    STAT_LEECH = 1100,
    STAT_AVOIDANCE = 1100,
    STAT_SPEED = 1100,
    Leech = 1100,
    Avoidance = 1100,
    Speed = 1100,
}

local STAT_DR_INFO = {
    STAT_CRIT = {
        baseCost = 138,
        tiers = {
            { limit = 1380, penalty = 1.0 },
            { limit = 1840, penalty = 0.9 },
            { limit = 2300, penalty = 0.8 },
        },
        lastPenalty = 0.7
    },
    STAT_HASTE = {
        baseCost = 132,
        tiers = {
            { limit = 1320, penalty = 1.0 },
            { limit = 1760, penalty = 0.9 },
            { limit = 2200, penalty = 0.8 },
        },
        lastPenalty = 0.7
    },
    STAT_MASTERY = {
        baseCost = 138,
        tiers = {
            { limit = 1380, penalty = 1.0 },
            { limit = 1840, penalty = 0.9 },
            { limit = 2300, penalty = 0.8 },
        },
        lastPenalty = 0.7
    },
    STAT_VERSATILITY = {
        baseCost = 162,
        tiers = {
            { limit = 1620, penalty = 1.0 },
            { limit = 2160, penalty = 0.9 },
            { limit = 2700, penalty = 0.8 },
        },
        lastPenalty = 0.7
    }
}

return function(ItemEvaluator)
    function ItemEvaluator:GetBaseRatingCost(statKey, combatRatingID)
        local info = STAT_DR_INFO[statKey]
        if info then return info.baseCost end
        if statKey == "STAT_CRIT" then return 138
        elseif statKey == "STAT_HASTE" then return 132
        elseif statKey == "STAT_MASTERY" then return 138
        elseif statKey == "STAT_VERSATILITY" then return 162
        end
        return 138
    end

    function ItemEvaluator:ConvertRatingToPercent(statKey, rating)
        if not rating or rating <= 0 then
            return 0
        end
        
        local info = STAT_DR_INFO[statKey]
        if not info then
            local cost = TERTIARY_BASE_COSTS[statKey] or 1100
            return rating / cost
        end
        
        local baseCost = info.baseCost
        local remaining = rating
        local totalPercent = 0
        local prevLimit = 0
        
        for _, tier in ipairs(info.tiers) do
            local tierSize = tier.limit - prevLimit
            if remaining > tierSize then
                totalPercent = totalPercent + (tierSize * tier.penalty / baseCost)
                remaining = remaining - tierSize
                prevLimit = tier.limit
            else
                totalPercent = totalPercent + (remaining * tier.penalty / baseCost)
                remaining = 0
                break
            end
        end
        
        if remaining > 0 then
            totalPercent = totalPercent + (remaining * info.lastPenalty / baseCost)
        end
        
        return totalPercent
    end

    function ItemEvaluator:ConvertPercentToRating(statKey, targetPercent)
        if not targetPercent or targetPercent <= 0 then
            return 0
        end
        
        local tertiaryCost = TERTIARY_BASE_COSTS[statKey]
        if tertiaryCost then
            return targetPercent * tertiaryCost
        end
        
        local info = STAT_DR_INFO[statKey]
        if not info then
            return targetPercent
        end
        
        local baseCost = info.baseCost
        local remaining = targetPercent
        local totalRating = 0
        local prevLimitPercent = 0
        local prevLimitRating = 0
        
        for _, tier in ipairs(info.tiers) do
            local tierSizeRating = tier.limit - prevLimitRating
            local tierSizePercent = (tierSizeRating * tier.penalty) / baseCost
            if remaining > tierSizePercent then
                totalRating = totalRating + tierSizeRating
                remaining = remaining - tierSizePercent
                prevLimitRating = tier.limit
            else
                totalRating = totalRating + (remaining * baseCost / tier.penalty)
                remaining = 0
                break
            end
        end
        
        if remaining > 0 then
            totalRating = totalRating + (remaining * baseCost / info.lastPenalty)
        end
        
        return totalRating
    end

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
end
