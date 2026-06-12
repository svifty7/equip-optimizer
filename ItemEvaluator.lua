-- ItemEvaluator.lua for EquipOptimizer
local addonName, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core

local ItemEvaluator = {}
addonTable.ItemEvaluator = ItemEvaluator

-- Constants for combat ratings
local CR_CRIT = 9
local CR_HASTE = 18
local CR_MASTERY = 26
local CR_VERSATILITY = 29
local CR_SPEED = 13
local CR_AVOIDANCE = 14
local CR_LIFESTEAL = 17

-- Base rating costs for tertiary stats (strictly linear, no DR)
local TERTIARY_BASE_COSTS = {
    STAT_LEECH = 1100,
    STAT_AVOIDANCE = 1100,
    STAT_SPEED = 1100,
    -- Also support friendly naming just in case
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

-- Stat key mapping from GetItemStats keys to internal keys
local StatKeyMapping = {}
local mappingDefinition = {
    -- Secondary stats
    ITEM_MOD_CRIT_RATING_SHORT = "STAT_CRIT",
    ITEM_MOD_CRIT_MELEE_SHORT = "STAT_CRIT",
    ITEM_MOD_CRIT_RANGED_SHORT = "STAT_CRIT",
    ITEM_MOD_CRIT_SPELL_SHORT = "STAT_CRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "STAT_HASTE",
    ITEM_MOD_HASTE_SHORT = "STAT_HASTE",
    ITEM_MOD_MASTERY_RATING_SHORT = "STAT_MASTERY",
    ITEM_MOD_MASTERY_SHORT = "STAT_MASTERY",
    ITEM_MOD_VERSATILITY = "STAT_VERSATILITY",
    
    -- Primary stats
    ITEM_MOD_INTELLECT_SHORT = "STAT_INTELLECT",
    ITEM_MOD_INTELLECT = "STAT_INTELLECT",
    ITEM_MOD_AGILITY_SHORT = "STAT_AGILITY",
    ITEM_MOD_AGILITY = "STAT_AGILITY",
    ITEM_MOD_STRENGTH_SHORT = "STAT_STRENGTH",
    ITEM_MOD_STRENGTH = "STAT_STRENGTH",
    ITEM_MOD_STAMINA_SHORT = "STAT_STAMINA",
    ITEM_MOD_STAMINA = "STAT_STAMINA",
    ITEM_MOD_ARMOR_SHORT = "STAT_ARMOR",
    ITEM_MOD_ARMOR = "STAT_ARMOR",
    
    -- Tertiary stats
    ITEM_MOD_CR_LIFESTEAL_SHORT = "STAT_LEECH",
    ITEM_MOD_CR_LIFESTEAL = "STAT_LEECH",
    ITEM_MOD_CR_AVOIDANCE_SHORT = "STAT_AVOIDANCE",
    ITEM_MOD_CR_AVOIDANCE = "STAT_AVOIDANCE",
    ITEM_MOD_CR_SPEED_SHORT = "STAT_SPEED",
    ITEM_MOD_CR_SPEED = "STAT_SPEED",
}

for constName, internalKey in pairs(mappingDefinition) do
    StatKeyMapping[constName] = internalKey
    local locVal = _G[constName]
    if locVal and type(locVal) == "string" then
        StatKeyMapping[locVal] = internalKey
    end
end

-- Slot ID to inventory types mapping
local SlotToTypes = {
    [1] = { "INVTYPE_HEAD" },
    [2] = { "INVTYPE_NECK" },
    [3] = { "INVTYPE_SHOULDER" },
    [15] = { "INVTYPE_BACK" },
    [5] = { "INVTYPE_CHEST", "INVTYPE_ROBE" },
    [9] = { "INVTYPE_WRIST" },
    [10] = { "INVTYPE_HAND" },
    [6] = { "INVTYPE_WAIST" },
    [7] = { "INVTYPE_LEGS" },
    [8] = { "INVTYPE_FEET" },
    [11] = { "INVTYPE_FINGER" },
    [12] = { "INVTYPE_FINGER" },
    [13] = { "INVTYPE_TRINKET" },
    [14] = { "INVTYPE_TRINKET" },
    [16] = { "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" },
    [17] = { "INVTYPE_WEAPON", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" }
}

-- Get combat rating conversion factors dynamically from character sheet
function ItemEvaluator:GetRatingPerPercent(ratingIndex)
    local rating = GetCombatRating(ratingIndex) or 0
    local percent = GetCombatRatingBonus(ratingIndex) or 0
    if percent > 0 then
        return rating / percent
    end
    
    -- Fallback levels based on WoW 11.x / 12.x scaling
    local level = UnitLevel("player") or 80
    if level >= 80 then
        if ratingIndex == CR_HASTE then return 660
        elseif ratingIndex == CR_CRIT then return 700
        elseif ratingIndex == CR_MASTERY then return 700
        elseif ratingIndex == CR_VERSATILITY then return 780
        end
    elseif level >= 70 then
        if ratingIndex == CR_HASTE then return 170
        elseif ratingIndex == CR_CRIT then return 180
        elseif ratingIndex == CR_MASTERY then return 180
        elseif ratingIndex == CR_VERSATILITY then return 205
        end
    end
    return 100 -- ultimate fallback
end

-- Get dynamic base rating cost for secondary stats or fallback to level 90 (Midnight)
function ItemEvaluator:GetBaseRatingCost(statKey, combatRatingID)
    local rating = GetCombatRating and GetCombatRating(combatRatingID) or 0
    local percent = GetCombatRatingBonus and GetCombatRatingBonus(combatRatingID) or 0
    if percent > 0 and percent < 30 then
        return rating / percent
    end
    
    -- Hardcoded constants for lvl 90 (Midnight)
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

-- Scrap stats and item level of an item
local function GetItemRatings(itemLink)
    local GetItemStats = C_Item and C_Item.GetItemStats or _G.GetItemStats
    local rawStats = GetItemStats(itemLink)
    local ratings = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_INTELLECT = 0,
        STAT_AGILITY = 0,
        STAT_STRENGTH = 0,
        STAT_STAMINA = 0,
        STAT_ARMOR = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
        STAT_ILVL = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
    }
    if rawStats then
        for rawKey, val in pairs(rawStats) do
            local mapped = StatKeyMapping[rawKey]
            if mapped then
                ratings[mapped] = ratings[mapped] + val
            end
        end
    end
    return ratings
end

-- Find all candidate items in bags for a slot
function ItemEvaluator:GetBagItemsForSlot(slotId)
    local items = {}
    local slotTypes = SlotToTypes[slotId]
    if not slotTypes then return items end
    
    local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = C_Item.GetItemInfoInstant(itemLink)
                if itemID and IsEquippableItem(itemLink) then
                    local _, _, _, _, _, _, _, _, equipType = GetItemInfo(itemLink)
                    if not equipType then
                        -- Async cache miss, request load
                        C_Item.RequestLoadItemDataByID(itemID)
                    else
                        local matches = false
                        for _, t in ipairs(slotTypes) do
                            if equipType == t then
                                matches = true
                                break
                            end
                        end
                        
                        if matches then
                            local ratings = GetItemRatings(itemLink)
                            local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
                            
                            -- Sum rating for sorting
                            local totalRating = 0
                            for _, val in pairs(ratings) do
                                totalRating = totalRating + val
                            end
                            
                            table.insert(items, {
                                bag = bag,
                                slot = slot,
                                link = itemLink,
                                ratings = ratings,
                                ilvl = ilvl,
                                totalRating = totalRating,
                                equipType = equipType,
                                isEquipped = false
                            })
                        end
                    end
                end
            end
        end
    end
    return items
end

-- Find all equipped items that could fit a slot
function ItemEvaluator:GetEquippedItemsForSlot(slotId)
    local items = {}
    local slotTypes = SlotToTypes[slotId]
    if not slotTypes then return items end
    
    for eqSlotId, _ in pairs(SlotToTypes) do
        local itemLink = GetInventoryItemLink("player", eqSlotId)
        if itemLink then
            local _, _, _, equipType = C_Item.GetItemInfoInstant(itemLink)
            if equipType then
                local matches = false
                for _, t in ipairs(slotTypes) do
                    if equipType == t then
                        matches = true
                        break
                    end
                end
                
                if matches then
                    local ratings = GetItemRatings(itemLink)
                    local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
                    
                    -- Sum rating for sorting
                    local totalRating = 0
                    for _, val in pairs(ratings) do
                        totalRating = totalRating + val
                    end
                    
                    table.insert(items, {
                        slotId = eqSlotId,
                        link = itemLink,
                        ratings = ratings,
                        ilvl = ilvl,
                        totalRating = totalRating,
                        equipType = equipType,
                        isEquipped = true
                    })
                end
            end
        end
    end
    return items
end

-- Get the total secondary and tertiary stats of currently equipped items
function ItemEvaluator:GetEquippedStats()
    local stats = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
    }
    for _, item in pairs(self.equipped or {}) do
        if item.ratings then
            for k in pairs(stats) do
                stats[k] = stats[k] + (item.ratings[k] or 0)
            end
        end
    end
    return stats
end

-- Calculate resulting player stats with a specific combination of items from scratch for secondary/tertiary stats
function ItemEvaluator:GetResultingStats(combination, currentStats, ratingPerPercent)
    local netStats = {
        STAT_INTELLECT = 0,
        STAT_AGILITY = 0,
        STAT_STRENGTH = 0,
        STAT_STAMINA = 0,
        STAT_ARMOR = 0,
        STAT_ILVL = 0,
    }
    
    local directStats = {
        STAT_CRIT = 0,
        STAT_HASTE = 0,
        STAT_MASTERY = 0,
        STAT_VERSATILITY = 0,
        STAT_LEECH = 0,
        STAT_AVOIDANCE = 0,
        STAT_SPEED = 0,
    }
    
    -- Check if combination has a 2H weapon in MainHand
    local has2H = false
    local mainHandItem = combination[16]
    if mainHandItem and mainHandItem.equipType == "INVTYPE_2HWEAPON" then
        has2H = true
    end
    
    for slotId, itemInfo in pairs(combination) do
        local actualItem = itemInfo
        if slotId == 17 and has2H then
            -- Force offhand to empty if wielding a 2H weapon, but set ilvl to main hand's ilvl
            actualItem = { ratings = { STAT_ILVL = mainHandItem.ilvl }, ilvl = mainHandItem.ilvl }
        end
        
        local equippedInfo = self.equipped[slotId]
        local eqRatings = equippedInfo and equippedInfo.ratings or {}
        local newRatings = actualItem.ratings or {}
        
        -- Delta for primary stats and ilvl
        for k in pairs(netStats) do
            local eqVal = eqRatings[k] or 0
            local newVal = newRatings[k] or 0
            netStats[k] = netStats[k] + (newVal - eqVal)
        end
        
        -- Direct sum for secondary and tertiary stats
        for k in pairs(directStats) do
            local newVal = newRatings[k] or 0
            directStats[k] = directStats[k] + newVal
        end
    end
    
    local resulting = {}
    
    -- Direct stats from items
    for k, v in pairs(directStats) do
        resulting[k] = v
    end
    
    -- Delta calculation for primary stats, armor, and item level
    resulting.STAT_INTELLECT = currentStats.STAT_INTELLECT + netStats.STAT_INTELLECT
    resulting.STAT_AGILITY = currentStats.STAT_AGILITY + netStats.STAT_AGILITY
    resulting.STAT_STRENGTH = currentStats.STAT_STRENGTH + netStats.STAT_STRENGTH
    resulting.STAT_STAMINA = currentStats.STAT_STAMINA + netStats.STAT_STAMINA
    resulting.STAT_ARMOR = currentStats.STAT_ARMOR + netStats.STAT_ARMOR
    resulting.STAT_ILVL = currentStats.STAT_ILVL + (netStats.STAT_ILVL / 16)
    
    return resulting
end

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

-- Perform search for best items combo
function ItemEvaluator:Optimize()
    local profile = Core.activeProfile
    local activeRules = {}
    if profile.rules then
        for _, r in ipairs(profile.rules) do
            if r.enabled then
                table.insert(activeRules, r)
            end
        end
    end
    
    -- Extract current character sheet stats
    local _, avgIlvl = GetAverageItemLevel()
    
    local currentStats = {
        STAT_CRIT = GetCombatRating(CR_CRIT) or 0,
        STAT_HASTE = GetCombatRating(CR_HASTE) or 0,
        STAT_MASTERY = GetCombatRating(CR_MASTERY) or 0,
        STAT_VERSATILITY = GetCombatRating(CR_VERSATILITY) or 0,
        STAT_LEECH = GetCombatRating(CR_LIFESTEAL) or 0,
        STAT_AVOIDANCE = GetCombatRating(CR_AVOIDANCE) or 0,
        STAT_SPEED = GetCombatRating(CR_SPEED) or 0,
        STAT_INTELLECT = select(2, UnitStat("player", 4)) or 0,
        STAT_AGILITY = select(2, UnitStat("player", 2)) or 0,
        STAT_STRENGTH = select(2, UnitStat("player", 1)) or 0,
        STAT_STAMINA = select(2, UnitStat("player", 3)) or 0,
        STAT_ARMOR = select(2, UnitArmor("player")) or 0,
        STAT_ILVL = avgIlvl or 0,
    }
    
    local ratingPerPercent = {
        STAT_CRIT = self:GetRatingPerPercent(CR_CRIT),
        STAT_HASTE = self:GetRatingPerPercent(CR_HASTE),
        STAT_MASTERY = self:GetRatingPerPercent(CR_MASTERY),
        STAT_VERSATILITY = self:GetRatingPerPercent(CR_VERSATILITY),
    }
    
    -- Scan currently equipped items
    self.equipped = {}
    local candidates = {}
    
    for _, slotInfo in ipairs(Core.Slots) do
        local slotId = slotInfo.id
        candidates[slotId] = {}
        
        local itemLink = GetInventoryItemLink("player", slotId)
        local eqItem = nil
        if itemLink then
            local ratings = GetItemRatings(itemLink)
            local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
            local _, _, _, _, _, _, _, _, equipType = C_Item.GetItemInfo(itemLink)
            
            eqItem = {
                link = itemLink,
                ratings = ratings,
                ilvl = ilvl,
                equipType = equipType,
                isEquipped = true,
                slotId = slotId
            }
            self.equipped[slotId] = eqItem
        else
            eqItem = { ratings = {}, ilvl = 0, link = nil, isEquipped = true, slotId = slotId }
            self.equipped[slotId] = eqItem
        end
        
        -- Adjust offhand slot item level if wielding a 2H weapon
        if slotId == 17 then
            local mainHand = self.equipped[16]
            if mainHand and mainHand.equipType == "INVTYPE_2HWEAPON" then
                eqItem.ratings.STAT_ILVL = mainHand.ilvl
                eqItem.ilvl = mainHand.ilvl
            end
        end
        
        table.insert(candidates[slotId], eqItem)
        
        -- Lock evaluation logic
        local lockVal = profile.lockedSlots[slotId]
        if not lockVal then
            local bagItems = self:GetBagItemsForSlot(slotId)
            
            table.sort(bagItems, function(a, b)
                if a.ilvl ~= b.ilvl then
                    return a.ilvl > b.ilvl
                end
                return a.totalRating > b.totalRating
            end)
            
            local limit = (slotId == 11 or slotId == 12 or slotId == 13 or slotId == 14 or slotId == 16 or slotId == 17) and 4 or 2
            
            local maxIlvl = eqItem.ilvl
            if #bagItems > 0 and bagItems[1].ilvl > maxIlvl then
                maxIlvl = bagItems[1].ilvl
            end
            
            local count = 0
            for _, item in ipairs(bagItems) do
                local allowedDiff = (slotId == 11 or slotId == 12 or slotId == 13 or slotId == 14) and 30 or 15
                if item.ilvl >= (maxIlvl - allowedDiff) then
                    table.insert(candidates[slotId], item)
                    count = count + 1
                    if count >= limit then break end
                end
            end
        else
            -- Slot IS locked!
            candidates[slotId] = {}
            if lockVal == true or lockVal == "equipped" then
                table.insert(candidates[slotId], eqItem)
            else
                -- It is a specific item link chosen by user
                local bagItems = self:GetBagItemsForSlot(slotId)
                local found = false
                for _, item in ipairs(bagItems) do
                    if item.link == lockVal then
                        table.insert(candidates[slotId], item)
                        found = true
                        break
                    end
                end
                if not found then
                    -- Check if it's currently equipped in any slot that fits
                    local equippedItems = self:GetEquippedItemsForSlot(slotId)
                    for _, item in ipairs(equippedItems) do
                        if item.link == lockVal then
                            table.insert(candidates[slotId], item)
                            found = true
                            break
                        end
                    end
                end
                if not found then
                    -- Fallback if selected item is no longer in bag/equipped
                    table.insert(candidates[slotId], eqItem)
                end
            end
        end
    end
    
    local eqStats = self:GetEquippedStats()
    for k, v in pairs(eqStats) do
        currentStats[k] = v
    end
    
    -- Filter optimizable slots
    local optimizableSlots = {}
    local currentComb = {}
    
    for slotId, slotCandidates in pairs(candidates) do
        if #slotCandidates == 1 then
            currentComb[slotId] = slotCandidates[1]
        else
            table.insert(optimizableSlots, slotId)
        end
    end
    
    -- Safety throttle to prevent freezing (cap total combinations)
    local totalCombinations = 1
    for _, slotId in ipairs(optimizableSlots) do
        totalCombinations = totalCombinations * #candidates[slotId]
    end
    
    if totalCombinations > 5000 then
        -- Prune candidates to top 1 bag item per slot
        for _, slotId in ipairs(optimizableSlots) do
            if #candidates[slotId] > 2 then
                candidates[slotId] = { candidates[slotId][1], candidates[slotId][2] }
            end
        end
    end
    
    -- Combinations search
    local bestCombination = nil
    
    local function GenerateCombinations(optIndex, usedBagItems)
        if optIndex > #optimizableSlots then
            -- Validate: 2H weapon vs OffHand
            local mainHand = currentComb[16]
            local offHand = currentComb[17]
            if mainHand and mainHand.equipType == "INVTYPE_2HWEAPON" then
                -- With 2H weapon, we only evaluate once using the first candidate of slot 17 to avoid duplicates
                if offHand ~= candidates[17][1] then
                    return
                end
            end
            
            -- Compute stats
            local stats = self:GetResultingStats(currentComb, currentStats, ratingPerPercent)
            local combNode = {
                items = {},
                stats = stats
            }
            for k, v in pairs(currentComb) do
                combNode.items[k] = v
            end
            
            if not bestCombination then
                bestCombination = combNode
            else
                if self:CompareCombinations(combNode, bestCombination, activeRules) then
                    bestCombination = combNode
                end
            end
            return
        end
        
        local slotId = optimizableSlots[optIndex]
        local slotCandidates = candidates[slotId]
        
        for _, cand in ipairs(slotCandidates) do
            local key = cand.bag and string.format("%d-%d", cand.bag, cand.slot) or (cand.isEquipped and cand.slotId and string.format("eq-%d", cand.slotId) or nil)
            if not key or not usedBagItems[key] then
                if key then usedBagItems[key] = true end
                currentComb[slotId] = cand
                
                GenerateCombinations(optIndex + 1, usedBagItems)
                
                currentComb[slotId] = nil
                if key then usedBagItems[key] = nil end
            end
        end
    end
    
    -- Start combination traversal
    local usedBagItems = {}
    GenerateCombinations(1, usedBagItems)
    
    -- Build recommendations list
    local recommendations = {}
    if bestCombination then
        local has2H = false
        local mainHandItem = bestCombination.items[16]
        if mainHandItem and mainHandItem.equipType == "INVTYPE_2HWEAPON" then
            has2H = true
        end
        
        for slotId, itemInfo in pairs(bestCombination.items) do
            local eqItem = self.equipped[slotId]
            local recItem = itemInfo
            
            if slotId == 17 and has2H then
                -- Off-hand must be empty if wielding a 2H weapon
                recItem = { link = nil, ilvl = 0, bag = nil, slot = nil }
            end
            
            -- If recommend item is different from equipped item
            if recItem.link ~= (eqItem and eqItem.link) then
                recommendations[slotId] = {
                    slotId = slotId,
                    currentLink = eqItem and eqItem.link or nil,
                    recommendedLink = recItem.link,
                    bag = recItem.bag,
                    slot = recItem.slot,
                    equippedSlot = recItem.isEquipped and recItem.slotId or nil,
                    ilvlDiff = recItem.ilvl - (eqItem and eqItem.ilvl or 0)
                }
            end
        end
    end
    
    return recommendations, bestCombination and bestCombination.stats or currentStats
end

-- Delayed Equipping Queue
local equipQueue = {}

function ItemEvaluator:EquipRecommended(recommendations)
    if InCombatLockdown() then
        UIFrameFadeIn(nil, 0, 0, 0) -- trigger warning
        return
    end
    
    -- Clear queue
    equipQueue = {}
    
    for slotId, rec in pairs(recommendations) do
        if rec.bag and rec.slot then
            table.insert(equipQueue, {
                slotId = slotId,
                bag = rec.bag,
                slot = rec.slot
            })
        elseif rec.equippedSlot then
            table.insert(equipQueue, {
                slotId = slotId,
                equippedSlot = rec.equippedSlot
            })
        end
    end
    
    if #equipQueue == 0 then
        return
    end
    
    self:ProcessNextEquip()
end

function ItemEvaluator:ProcessNextEquip()
    if InCombatLockdown() then
        -- Cancel queue if combat starts mid-equip
        equipQueue = {}
        return
    end
    
    if #equipQueue == 0 then
        return
    end
    
    local action = table.remove(equipQueue, 1)
    
    if action.bag and action.slot then
        local currentLink = C_Container.GetContainerItemLink(action.bag, action.slot)
        if currentLink then
            ClearCursor()
            C_Container.PickupContainerItem(action.bag, action.slot)
            EquipCursorItem(action.slotId)
            ClearCursor()
        end
    elseif action.equippedSlot then
        local currentLink = GetInventoryItemLink("player", action.equippedSlot)
        if currentLink then
            ClearCursor()
            PickupInventoryItem(action.equippedSlot)
            EquipCursorItem(action.slotId)
            ClearCursor()
        end
    end
    
    if #equipQueue > 0 then
        C_Timer.After(0.1, function()
            self:ProcessNextEquip()
        end)
    end
end
