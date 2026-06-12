-- GemEvaluator.lua for EquipOptimizer
local _, addonTable = ...
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator

-- Retrieve GemDB from external file
local GemDB = ItemEvaluator.GemDB

-- Request the client to pre-cache details of these gems
function ItemEvaluator:RequestLoadGems()
    if not C_Item or not C_Item.RequestLoadItemDataByID then return end
    for _, gemData in pairs(GemDB) do
        for _, gemId in pairs(gemData.ids) do
            C_Item.RequestLoadItemDataByID(gemId)
        end
    end
end

-- Find a gem's family and rank in the database
function ItemEvaluator:FindGemInDB(gemId)
    for family, gemData in pairs(GemDB) do
        for rank, id in pairs(gemData.ids) do
            if id == gemId then
                return family, rank, gemData
            end
        end
    end
    return nil, nil, nil
end
-- Get scaled/calculated stats of a gem by rank directly from GemDB
function ItemEvaluator:ScaleGem(gemFamily, quality)
    local gemData = GemDB[gemFamily]
    if not gemData then return nil, nil end
    
    local targetQuality = quality or 2
    if targetQuality > 2 then
        targetQuality = 2
    elseif targetQuality < 1 then
        targetQuality = 1
    end
    
    local gemId = gemData.ids[targetQuality]
    if not gemId then
        targetQuality = next(gemData.ids)
        gemId = gemData.ids[targetQuality]
    end
    
    local scaledStats = {
        STAT_CRIT = 0, STAT_HASTE = 0, STAT_MASTERY = 0, STAT_VERSATILITY = 0,
        STAT_INTELLECT = 0, STAT_AGILITY = 0, STAT_STRENGTH = 0, STAT_STAMINA = 0,
        STAT_LEECH = 0, STAT_AVOIDANCE = 0, STAT_SPEED = 0, STAT_ARMOR = 0,
    }
    
    local statsSource = gemData.stats[targetQuality]
    if statsSource then
        for statKey, val in pairs(statsSource) do
            if statKey == "STAT_PRIMARY" then
                local activePrimary = self:GetActivePrimaryStat()
                scaledStats[activePrimary] = (scaledStats[activePrimary] or 0) + val
            else
                scaledStats[statKey] = val
            end
        end
    end
    
    return gemId, scaledStats
end

local tooltipScanner = CreateFrame("GameTooltip", "EquipOptimizerGemScanner", nil, "GameTooltipTemplate")
tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local STAT_PATTERNS = {
    { pat = "speed", key = "STAT_SPEED" }, { pat = "передвиж", key = "STAT_SPEED" },
    { pat = "has", key = "STAT_HASTE" }, { pat = "скор", key = "STAT_HASTE" },
    { pat = "crit", key = "STAT_CRIT" }, { pat = "крит", key = "STAT_CRIT" },
    { pat = "mast", key = "STAT_MASTERY" }, { pat = "искус", key = "STAT_MASTERY" },
    { pat = "vers", key = "STAT_VERSATILITY" }, { pat = "универ", key = "STAT_VERSATILITY" },
    { pat = "int", key = "STAT_INTELLECT" }, { pat = "интел", key = "STAT_INTELLECT" },
    { pat = "agi", key = "STAT_AGILITY" }, { pat = "ловк", key = "STAT_AGILITY" },
    { pat = "str", key = "STAT_STRENGTH" }, { pat = "сил", key = "STAT_STRENGTH" },
    { pat = "stam", key = "STAT_STAMINA" }, { pat = "вынос", key = "STAT_STAMINA" },
    { pat = "leech", key = "STAT_LEECH" }, { pat = "самоисц", key = "STAT_LEECH" },
    { pat = "avoid", key = "STAT_AVOIDANCE" }, { pat = "избеж", key = "STAT_AVOIDANCE" }
}
ItemEvaluator.STAT_PATTERNS = STAT_PATTERNS

-- Get stats of a gem by ID mapped to internal keys (checks GemDB first, tooltip parsing is disabled)
function ItemEvaluator:GetGemStats(gemId)
    local family, rank = self:FindGemInDB(gemId)
    if family then
        local _, stats = self:ScaleGem(family, rank)
        return stats
    end

    local ratings = {
        STAT_CRIT = 0, STAT_HASTE = 0, STAT_MASTERY = 0, STAT_VERSATILITY = 0,
        STAT_INTELLECT = 0, STAT_AGILITY = 0, STAT_STRENGTH = 0, STAT_STAMINA = 0,
        STAT_LEECH = 0, STAT_AVOIDANCE = 0, STAT_SPEED = 0,
    }
    return ratings
end


function ItemEvaluator:GetActivePrimaryStat()
    local _, str = UnitStat("player", 1)
    local _, agi = UnitStat("player", 2)
    local _, int = UnitStat("player", 4)
    
    str = str or 0
    agi = agi or 0
    int = int or 0
    
    if str >= agi and str >= int then
        return "STAT_STRENGTH"
    elseif agi >= str and agi >= int then
        return "STAT_AGILITY"
    else
        return "STAT_INTELLECT"
    end
end


-- Calculate score of a gem based on character's active stat rules priority
function ItemEvaluator:ScoreGemStats(gemStats, activeRules)
    local score = 0
    
    local numActive = #activeRules
    local primaryWeight = (numActive + 1.5) * 30
    local activePrimary = self:GetActivePrimaryStat()
    local primaryVal = gemStats[activePrimary] or 0
    score = score + (primaryVal * primaryWeight)
    
    for idx, rule in ipairs(activeRules) do
        if rule.enabled and rule.stat ~= "STAT_ILVL" then
            local statVal = gemStats[rule.stat] or 0
            local weight = (numActive - idx + 1)
            score = score + (statVal * weight)
        end
    end
    
    -- Small fallback sum of stats so gems are always sorted reasonably even if rules are empty
    local sum = (gemStats.STAT_HASTE or 0) + (gemStats.STAT_CRIT or 0) + (gemStats.STAT_MASTERY or 0) + (gemStats.STAT_VERSATILITY or 0) + 
                (gemStats.STAT_LEECH or 0) + (gemStats.STAT_AVOIDANCE or 0) + (gemStats.STAT_SPEED or 0) + (gemStats.STAT_ARMOR or 0) + primaryVal

    return score + (sum * 0.0001)
end


-- Helper to parse socket information of any item link
function ItemEvaluator:ParseItemSockets(itemLink)
    local itemStats = C_Item.GetItemStats(itemLink)
    local numEmptyPrismatic = itemStats and itemStats.EMPTY_SOCKET_PRISMATIC or 0
    local numEmptyOther = 0
    if itemStats then
        for k, v in pairs(itemStats) do
            if k:find("^EMPTY_SOCKET_") and k ~= "EMPTY_SOCKET_PRISMATIC" then
                numEmptyOther = numEmptyOther + v
            end
        end
    end
    local totalEmpty = numEmptyPrismatic + numEmptyOther
    
    local itemString = string.match(itemLink, "item:([%-?%d:]+)")
    local filledGems = {}
    if itemString then
        local parts = { strsplit(":", itemString) }
        for i = 3, 6 do
            local gemId = tonumber(parts[i]) or 0
            if gemId > 0 then
                table.insert(filledGems, gemId)
            end
        end
    end
    
    local totalSockets = math.max(totalEmpty, #filledGems)
    if totalSockets > 0 then
        return {
            totalSockets = totalSockets,
            filledGems = filledGems,
            emptySockets = math.max(0, totalSockets - #filledGems)
        }
    end
    return nil
end

-- Get the stats of the highest scoring gem for the current rules
function ItemEvaluator:GetBestGemStats(activeRules)
    local profile = Core.activeProfile
    local chosenQuality = profile.gemQuality or 2
    local bestScore = -1
    local bestStats = nil
    
    for family, gemData in pairs(GemDB) do
        if not gemData.isMeta then
            local gemId, gemStats = self:ScaleGem(family, chosenQuality)
            if gemId then
                local score = self:ScoreGemStats(gemStats, activeRules)
                if score > bestScore then
                    bestScore = score
                    bestStats = gemStats
                end
            end
        end
    end
    
    if not bestStats then
        bestStats = {
            STAT_CRIT = 0, STAT_HASTE = 0, STAT_MASTERY = 0, STAT_VERSATILITY = 0,
            STAT_INTELLECT = 0, STAT_AGILITY = 0, STAT_STRENGTH = 0, STAT_STAMINA = 0,
            STAT_LEECH = 0, STAT_AVOIDANCE = 0, STAT_SPEED = 0, STAT_ARMOR = 0,
        }
    end
    return bestStats
end

-- Retrieve evaluated gems and check equipped & recommended item sockets
function ItemEvaluator:GetSocketRecommendations()
    local activeRules = {}
    local profile = Core.activeProfile
    if profile.rules then
        for _, r in ipairs(profile.rules) do
            if r.enabled then
                table.insert(activeRules, r)
            end
        end
    end
    
    -- 1. Score all candidate gems
    local gems = {}
    local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local chosenQuality = profile.gemQuality or 2
    
    for family, gemData in pairs(GemDB) do
        local gemId, gemStats = self:ScaleGem(family, chosenQuality)
        if gemId then
            local score = self:ScoreGemStats(gemStats, activeRules)
            local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(gemId)
            table.insert(gems, {
                id = gemId,
                family = family,
                name = name or ("Item " .. gemId),
                link = link or ("item:" .. gemId),
                quality = quality or 1,
                icon = icon or 134400, -- default question mark icon
                stats = gemStats,
                score = score
            })
        end
    end
    
    -- Sort evaluated gems in descending order of their score
    table.sort(gems, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.id > b.id
    end)
    
    local function addSocketInfo(list, slotInfo, link, extraInfo)
        local info = self:ParseItemSockets(link)
        if info then
            info.slotId, info.slotName, info.slotLabel, info.link = slotInfo.id, slotInfo.name, slotInfo.label, link
            if extraInfo then
                info.bag = extraInfo.bag
                info.slot = extraInfo.slot
                info.equippedSlot = extraInfo.equippedSlot
            end
            table.insert(list, info)
        end
    end

    -- 2. Inspect equipped items for sockets
    local equippedSockets = {}
    for _, slotInfo in ipairs(Core.Slots) do
        local itemLink = GetInventoryItemLink("player", slotInfo.id)
        if itemLink then
            addSocketInfo(equippedSockets, slotInfo, itemLink, { equippedSlot = slotInfo.id })
        end
    end
    
    -- 3. Inspect recommended items for sockets
    local recommendedSockets = {}
    local recommendations = self:Optimize()
    for _, slotInfo in ipairs(Core.Slots) do
        local rec = recommendations[slotInfo.id]
        if rec and rec.recommendedLink then
            addSocketInfo(recommendedSockets, slotInfo, rec.recommendedLink, {
                bag = rec.bag,
                slot = rec.slot,
                equippedSlot = rec.equippedSlot
            })
        end
    end
    
    return gems, equippedSockets, recommendedSockets
end
