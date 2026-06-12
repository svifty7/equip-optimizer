-- SetRequirements.lua for EquipOptimizer
local addonName, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

function UI:DrawSetRequirements(settingsContainer, leftColumn, rightColumn)
    local bottomColumn = self:CreateBackdropFrame(settingsContainer, L.SET_REQUIREMENTS or "Set Requirements")
    bottomColumn:SetSize(395, 140)
    bottomColumn:SetPoint("TOPLEFT", leftColumn, "BOTTOMLEFT", 0, -15)
    
    local bottomScroll, bottomChild = self:CreateScrollFrame(bottomColumn, 395, 116)
    bottomScroll:SetPoint("TOPLEFT", bottomColumn, "TOPLEFT", 10, -12)
    
    local sets = ItemEvaluator:GetAvailableSets()
    local ownedCounts = ItemEvaluator:GetOwnedSetCounts()
    
    local offsetY = 0
    
    if #sets == 0 then
        local noSets = bottomChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        noSets:SetPoint("TOPLEFT", bottomChild, "TOPLEFT", 10, -10)
        noSets:SetText(L.NO_SETS_FOUND or "No item sets detected in bags or equipped!")
        offsetY = offsetY + 30
    else
        for _, set in ipairs(sets) do
            local setID = set.id
            local count = ownedCounts[setID] or 0
            
            local row = CreateFrame("Frame", nil, bottomChild)
            row:SetSize(355, 26)
            row:SetPoint("TOPLEFT", bottomChild, "TOPLEFT", 0, -offsetY)
            
            local lblName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lblName:SetPoint("LEFT", row, "LEFT", 0, 0)
            lblName:SetText(string.format(L.SET_COUNT_FORMAT or "%s (owned: %d)", set.name, count))
            lblName:SetWidth(190)
            lblName:SetJustifyH("LEFT")
            
            local ddMin = self:CreateDropdown(row, 155, "")
            ddMin:SetPoint("LEFT", row, "LEFT", 200, 0)
            
            local currentVal = Core.activeProfile.requiredSets and Core.activeProfile.requiredSets[setID] or 0
            local function UpdateDropdownText()
                if currentVal == 0 then
                    ddMin.text:SetText(L.SET_NONE or "None")
                    ddMin.text:SetTextColor(0.6, 0.6, 0.6, 1)
                else
                    ddMin.text:SetText(string.format("%d %s", currentVal, L.SET_PIECES or "pieces"))
                    ddMin.text:SetTextColor(1, 0.82, 0, 1)
                end
            end
            UpdateDropdownText()
            
            ddMin:SetScript("OnClick", function()
                local list = {
                    [0] = L.SET_NONE or "None"
                }
                local maxVal = math.max(set.maxItems or 5, currentVal)
                for i = 2, maxVal do
                    list[i] = string.format("%d %s", i, L.SET_PIECES or "pieces")
                end
                self:OpenDropdownMenu(ddMin, list, currentVal, function(key)
                    currentVal = key
                    if not Core.activeProfile.requiredSets then
                        Core.activeProfile.requiredSets = {}
                    end
                    if key == 0 then
                        Core.activeProfile.requiredSets[setID] = nil
                    else
                        Core.activeProfile.requiredSets[setID] = key
                    end
                    UpdateDropdownText()
                    
                    ItemEvaluator:Optimize()
                    if self:IsWindowOpen() and self.mainWindow.selectedTab == "recs" then
                        self:Refresh()
                    end
                end)
            end)
            
            offsetY = offsetY + 28
        end
    end
    
    bottomChild:SetHeight(offsetY)
end
