-- ReservedSlots.lua for EquipOptimizer
local _, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

function UI:DrawReservedSlots(settingsContainer, profilePanel)
    local leftColumn = self:CreateBackdropFrame(settingsContainer, L.SLOT_LOCKS or "Reserved Slots")
    leftColumn:SetSize(395, 200)
    leftColumn:SetPoint("TOPLEFT", profilePanel, "BOTTOMLEFT", 0, -15)
    
    local leftScroll, leftChild = self:CreateScrollFrame(leftColumn, 395, 176)
    leftScroll:SetPoint("TOPLEFT", leftColumn, "TOPLEFT", 10, -12)
    
    local offsetY = 0
    for _, slotInfo in ipairs(Core.Slots) do
        local slotId = slotInfo.id
        
        local row = CreateFrame("Frame", nil, leftChild)
        row:SetSize(355, 26)
        row:SetPoint("TOPLEFT", leftChild, "TOPLEFT", 0, -offsetY)
        
        local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("LEFT", row, "LEFT", 0, 0)
        cb.Text:SetText(L[slotInfo.label] or slotInfo.name)
        cb.Text:SetFontObject(GameFontHighlight)
        cb:SetChecked(Core.activeProfile.lockedSlots[slotId] ~= nil)
        
        local ddBtn = self:CreateDropdown(row, 200, "")
        ddBtn:SetPoint("LEFT", row, "LEFT", 155, 0)
        
        local function UpdateDropdownState()
            local lockVal = Core.activeProfile.lockedSlots[slotId]
            if lockVal == nil then
                ddBtn:Disable()
                ddBtn:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
                ddBtn.text:SetTextColor(0.4, 0.4, 0.4, 1)
                ddBtn.text:SetText(L.CURRENTLY_EQUIPPED)
            else
                ddBtn:Enable()
                ddBtn:SetBackdropColor(0, 0, 0, 0.6)
                ddBtn.text:SetTextColor(1, 0.82, 0, 1)
                if lockVal == true or lockVal == "equipped" then
                    ddBtn.text:SetText(L.CURRENTLY_EQUIPPED)
                else
                    ddBtn.text:SetText(lockVal)
                end
            end
        end
        UpdateDropdownState()
        
        cb:SetScript("OnClick", function(btnCb)
            local checked = btnCb:GetChecked()
            if checked then
                Core.activeProfile.lockedSlots[slotId] = "equipped"
            else
                Core.activeProfile.lockedSlots[slotId] = nil
            end
            UpdateDropdownState()
            self:OnSettingsChanged()
        end)
        
        ddBtn:SetScript("OnClick", function()
            local list = {}
            list["equipped"] = L.CURRENTLY_EQUIPPED
            
            local equippedItems = ItemEvaluator:GetEquippedItemsForSlot(slotId)
            for _, item in ipairs(equippedItems) do
                list[item.link] = {
                    text = item.link,
                    tooltipData = {
                        isEquipped = true,
                        slotId = item.slotId
                    }
                }
            end
            
            local bagItems = ItemEvaluator:GetBagItemsForSlot(slotId)
            for _, item in ipairs(bagItems) do
                list[item.link] = {
                    text = item.link,
                    tooltipData = {
                        isEquipped = false,
                        bag = item.bag,
                        slot = item.slot
                    }
                }
            end
            
            local lockVal = Core.activeProfile.lockedSlots[slotId] or "equipped"
            self:OpenDropdownMenu(ddBtn, list, lockVal, function(key)
                Core.activeProfile.lockedSlots[slotId] = key
                UpdateDropdownState()
                self:OnSettingsChanged()
            end)
        end)
        
        offsetY = offsetY + 28
    end
    leftChild:SetHeight(offsetY)
    return leftColumn
end
