-- EquipQueue.lua for EquipOptimizer
local addonName, addonTable = ...
local ItemEvaluator = addonTable.ItemEvaluator

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
    
    -- Schedule next item equip in queue after a very short delay
    C_Timer.After(0.1, function()
        self:ProcessNextEquip()
    end)
end
