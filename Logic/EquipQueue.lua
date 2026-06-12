-- EquipQueue.lua for EquipOptimizer
local addonName, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

-- Delayed Equipping Queue
local equipQueue = {}
local equipQueueTargetLinks = {}

local function GetItemString(link)
    if not link then return nil end
    return link:match("|H(.-)|h")
end

local function IsBagItemLocked(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if type(info) == "table" then
            return info.isLocked
        elseif info then
            return select(3, C_Container.GetContainerItemInfo(bag, slot))
        end
    end
    if GetContainerItemInfo then
        local _, _, locked = GetContainerItemInfo(bag, slot)
        return locked
    end
    return false
end

local function IsUnboundBoE(link, bag, slot)
    if not link then return false end
    local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(link)
    
    if not bindType then
        local itemID = C_Item.GetItemInfoInstant(link)
        if itemID then
            _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(itemID)
        end
    end
    
    if bindType == 2 or bindType == 3 then
        -- It is BoE (2) or BoU (3). Check if it is bound.
        if bag and slot then
            if C_Container and C_Container.GetContainerItemInfo then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if type(info) == "table" then
                    return not info.isBound
                elseif info then
                     return not select(11, C_Container.GetContainerItemInfo(bag, slot))
                end
            end
            if GetContainerItemInfo then
                local _, _, _, _, _, _, _, _, _, _, isBound = GetContainerItemInfo(bag, slot)
                return not isBound
            end
        end
    end
    return false
end

local function FindItemLocation(targetLink, slotId)
    local targetStr = GetItemString(targetLink)
    if not targetStr then return nil end
    
    -- 1. Check bags first (prefer bag items over already equipped items to avoid slot swapping)
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if GetItemString(link) == targetStr then
                return { bag = bag, slot = slot }
            end
        end
    end
    
    -- 2. Check inventory slots, ignoring slots that are already correctly equipped
    for s = 1, 19 do
        if s ~= slotId then
            local currentLink = GetInventoryItemLink("player", s)
            if GetItemString(currentLink) == targetStr then
                -- Check if slot s is already correctly equipped according to recommendations
                local isCorrect = false
                local targetForS = equipQueueTargetLinks[s]
                if targetForS and GetItemString(currentLink) == GetItemString(targetForS) then
                    isCorrect = true
                end
                
                if not isCorrect then
                    return { equippedSlot = s }
                end
            end
        end
    end
    
    return nil
end

function ItemEvaluator:EquipRecommended(recommendations)
    if InCombatLockdown() then
        UIFrameFadeIn(nil, 0, 0, 0) -- trigger warning
        return
    end
    
    -- Clear queue
    equipQueue = {}
    equipQueueTargetLinks = {}
    
    for slotId, rec in pairs(recommendations) do
        if rec.recommendedLink then
            -- Skip automatic equipping of unbound Bind-on-Equip/Bind-on-Use items
            local isUnboundBoE = false
            if rec.bag and rec.slot then
                isUnboundBoE = IsUnboundBoE(rec.recommendedLink, rec.bag, rec.slot)
            end
            
            if not isUnboundBoE then
                equipQueueTargetLinks[slotId] = rec.recommendedLink
                table.insert(equipQueue, {
                    slotId = slotId,
                    targetLink = rec.recommendedLink,
                    attempts = 0
                })
            end
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
        equipQueueTargetLinks = {}
        local UI = addonTable.UI
        if UI and UI.IsWindowOpen and UI:IsWindowOpen() then
            UI:Refresh()
        end
        return
    end
    
    if #equipQueue == 0 then
        local UI = addonTable.UI
        if UI and UI.IsWindowOpen and UI:IsWindowOpen() then
            UI:Refresh()
        end
        return
    end
    
    local action = equipQueue[1]
    
    -- 1. Check if the slot already has the target item equipped
    local currentLink = GetInventoryItemLink("player", action.slotId)
    if GetItemString(currentLink) == GetItemString(action.targetLink) then
        -- Success! Pop from queue and move to next
        table.remove(equipQueue, 1)
        self:ProcessNextEquip()
        return
    end
    
    -- 2. Check if we exceeded retry limit (e.g. 60 attempts)
    if action.attempts >= 60 then
        -- Failed/ignored. Remove from queue to prevent freeze.
        table.remove(equipQueue, 1)
        self:ProcessNextEquip()
        return
    end
    
    -- 3. Dynamically find the item location
    local loc = FindItemLocation(action.targetLink, action.slotId)
    if not loc then
        -- Increment attempts so we don't retry infinitely if the item is truly gone
        action.attempts = action.attempts + 1
        C_Timer.After(0.05, function()
            self:ProcessNextEquip()
        end)
        return
    end
    
    -- 4. Check lock states / busy status
    local isBusy = false
    
    if CursorHasItem() then
        isBusy = true
    end
    
    if IsInventoryItemLocked(action.slotId) then
        isBusy = true
    end
    
    if loc.bag and loc.slot then
        if IsBagItemLocked(loc.bag, loc.slot) then
            isBusy = true
        end
    elseif loc.equippedSlot then
        if IsInventoryItemLocked(loc.equippedSlot) then
            isBusy = true
        end
    end
    
    if isBusy then
        -- Wait and retry this action later
        C_Timer.After(0.05, function()
            self:ProcessNextEquip()
        end)
        return
    end
    
    -- If we already sent the equip command, we just wait for it to complete.
    if action.equippedStarted then
        action.attempts = action.attempts + 1
        C_Timer.After(0.05, function()
            self:ProcessNextEquip()
        end)
        return
    end
    
    -- 5. Perform the equip action
    action.equippedStarted = true
    action.attempts = action.attempts + 1
    
    if loc.bag and loc.slot then
        local sourceLink = C_Container.GetContainerItemLink(loc.bag, loc.slot)
        if sourceLink then
            ClearCursor()
            C_Container.PickupContainerItem(loc.bag, loc.slot)
            EquipCursorItem(action.slotId)
            ClearCursor()
        else
            -- Source item is missing! Skip
            table.remove(equipQueue, 1)
        end
    elseif loc.equippedSlot then
        local sourceLink = GetInventoryItemLink("player", loc.equippedSlot)
        if sourceLink then
            ClearCursor()
            PickupInventoryItem(loc.equippedSlot)
            EquipCursorItem(action.slotId)
            ClearCursor()
        else
            -- Source item is missing! Skip
            table.remove(equipQueue, 1)
        end
    end
    
    -- Schedule next check after a very short delay
    C_Timer.After(0.05, function()
        self:ProcessNextEquip()
    end)
end

function ItemEvaluator:IsEquipQueueActive()
    return #equipQueue > 0
end
