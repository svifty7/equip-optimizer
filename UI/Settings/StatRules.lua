-- StatRules.lua for EquipOptimizer
local _, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

function UI:DrawStatRules(settingsContainer, profilePanel)
    local rightColumn = self:CreateBackdropFrame(settingsContainer, L.RULES or "Stat Rules")
    rightColumn:SetSize(400, 355)
    rightColumn:SetPoint("TOPLEFT", profilePanel, "BOTTOMLEFT", 410, -15)
    
    local helpBtn = CreateFrame("Button", nil, rightColumn)
    helpBtn:SetSize(20, 20)
    helpBtn:SetPoint("TOPRIGHT", rightColumn, "TOPRIGHT", -12, 8)
    
    local helpText = helpBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpText:SetPoint("CENTER", helpBtn, "CENTER", 0, 0)
    helpText:SetText("[?]")
    helpText:SetTextColor(0.8, 0.8, 0.8, 1)
    
    helpBtn:SetScript("OnEnter", function(btnHelp)
        helpText:SetTextColor(1, 0.82, 0, 1)
        GameTooltip:SetOwner(btnHelp, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L.HELP_TOOLTIP_TITLE or "How to configure stats:", 1, 0.82, 0)
        GameTooltip:AddLine(L.HELP_TOOLTIP_MIN or "", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(L.HELP_TOOLTIP_MAX or "", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(L.HELP_TOOLTIP_ORDER or "", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(L.HELP_TOOLTIP_PRIMARY or "", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function()
        helpText:SetTextColor(0.8, 0.8, 0.8, 1)
        GameTooltip:Hide()
    end)
    
    local rightScroll, rightChild = self:CreateScrollFrame(rightColumn, 400, 331)
    rightScroll:SetPoint("TOPLEFT", rightColumn, "TOPLEFT", 10, -12)
    
    local function RefreshRulesList()
        local children = { rightChild:GetChildren() }
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        
        local rules = Core.activeProfile.rules or {}
        local yOffset = 0
        
        local function IsTertiaryStat(statKey)
            return statKey == "STAT_LEECH" or statKey == "STAT_AVOIDANCE" or statKey == "STAT_SPEED"
        end
        
        local renderedSecondaryHeader = false
        local renderedTertiaryHeader = false
        
        for idx, rule in ipairs(rules) do
            if rule.stat ~= "STAT_ILVL" then
                local isTert = IsTertiaryStat(rule.stat)
                
                -- Render section header if needed
                if not isTert and not renderedSecondaryHeader then
                    renderedSecondaryHeader = true
                    
                    local headerRow = CreateFrame("Frame", nil, rightChild)
                    headerRow:SetSize(370, 18)
                    headerRow:SetPoint("TOPLEFT", rightChild, "TOPLEFT", 0, -yOffset)
                    
                    local headerText = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    headerText:SetPoint("LEFT", headerRow, "LEFT", 5, 0)
                    headerText:SetText(L.STAT_GROUP_SECONDARY or "Secondary Stats")
                    headerText:SetTextColor(1, 0.82, 0, 1) -- Golden color
                    
                    local line = headerRow:CreateTexture(nil, "ARTWORK")
                    line:SetSize(360, 1)
                    line:SetColorTexture(0.3, 0.3, 0.3, 0.4)
                    line:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 5, -2)
                    
                    yOffset = yOffset + 24
                elseif isTert and not renderedTertiaryHeader then
                    renderedTertiaryHeader = true
                    
                    local headerRow = CreateFrame("Frame", nil, rightChild)
                    headerRow:SetSize(370, 18)
                    headerRow:SetPoint("TOPLEFT", rightChild, "TOPLEFT", 0, -yOffset)
                    
                    local headerText = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    headerText:SetPoint("LEFT", headerRow, "LEFT", 5, 0)
                    headerText:SetText(L.STAT_GROUP_TERTIARY or "Tertiary Stats")
                    headerText:SetTextColor(1, 0.82, 0, 1) -- Golden color
                    
                    local line = headerRow:CreateTexture(nil, "ARTWORK")
                    line:SetSize(360, 1)
                    line:SetColorTexture(0.3, 0.3, 0.3, 0.4)
                    line:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 5, -2)
                    
                    yOffset = yOffset + 24
                end
                
                local row = CreateFrame("Frame", nil, rightChild)
                row:SetSize(370, 28)
                row:SetPoint("TOPLEFT", rightChild, "TOPLEFT", 0, -yOffset)
                
                local baseText = L[rule.stat] or rule.stat
                local currentVal = 0
                local currentPct = 0
                local isPercent = false
                
                local currentStats = ItemEvaluator:GetPlayerCurrentStats()
                local basePct = ItemEvaluator:GetBaseStatPercentages()
                currentVal = currentStats[rule.stat] or 0
                if rule.stat == "STAT_HASTE" or rule.stat == "STAT_CRIT" or rule.stat == "STAT_MASTERY" or rule.stat == "STAT_VERSATILITY" then
                    local bp = basePct[rule.stat] or 0
                    currentPct = bp + ItemEvaluator:ConvertRatingToPercent(rule.stat, currentVal)
                    isPercent = true
                elseif rule.stat == "STAT_LEECH" or rule.stat == "STAT_AVOIDANCE" or rule.stat == "STAT_SPEED" then
                    currentPct = ItemEvaluator:ConvertRatingToPercent(rule.stat, currentVal)
                    isPercent = true
                end
                
                local cleanText = baseText:gsub(" ?%(%%%)", "")
                local displayText = string.format("%s (%d)", cleanText, currentVal)
                
                local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                lbl:SetPoint("LEFT", row, "LEFT", 5, 0)
                lbl:SetText(displayText)
                lbl:SetWidth(210)
                lbl:SetJustifyH("LEFT")
                
                local valFrame, valEB = self:CreateEditBox(row, 45, 20, "")
                valFrame:SetPoint("LEFT", row, "LEFT", 220, 0)
                valEB:SetText(rule.value and tostring(rule.value) or "")
                
                local btnUp = CreateFrame("Button", nil, row)
                btnUp:SetSize(22, 22)
                btnUp:SetPoint("LEFT", valFrame, "RIGHT", 15, 0)
                btnUp:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
                btnUp:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
                btnUp:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
                btnUp:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                
                local isTert = IsTertiaryStat(rule.stat)
                
                local disableUp = (idx <= 2) or (IsTertiaryStat(rules[idx-1].stat) ~= isTert)
                if disableUp then
                    btnUp:Disable()
                end
                
                local btnDown = CreateFrame("Button", nil, row)
                btnDown:SetSize(22, 22)
                btnDown:SetPoint("LEFT", btnUp, "RIGHT", 5, 0)
                btnDown:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
                btnDown:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
                btnDown:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
                btnDown:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                
                local disableDown = (idx == #rules) or (IsTertiaryStat(rules[idx+1].stat) ~= isTert)
                if disableDown then
                    btnDown:Disable()
                end
                
                local function ValidateValue(selfEb)
                    local valStr = selfEb:GetText()
                    if valStr == "" then
                        rule.value = nil
                        selfEb:SetText("")
                        return
                    end
                    local val = tonumber(valStr)
                    if not val or val <= 0 then
                        rule.value = nil
                        selfEb:SetText("")
                    else
                        rule.value = val
                        selfEb:SetText(tostring(val))
                    end
                end
                
                valEB:SetScript("OnEnterPressed", function(selfEb)
                    ValidateValue(selfEb)
                    selfEb:ClearFocus()
                    self:OnSettingsChanged()
                end)
                valEB:SetScript("OnEditFocusLost", function(selfEb)
                    ValidateValue(selfEb)
                    self:OnSettingsChanged()
                end)
                
                btnUp:SetScript("OnClick", function()
                    local tmp = rules[idx]
                    rules[idx] = rules[idx-1]
                    rules[idx-1] = tmp
                    RefreshRulesList()
                    self:OnSettingsChanged()
                end)
                
                btnDown:SetScript("OnClick", function()
                    local tmp = rules[idx]
                    rules[idx] = rules[idx+1]
                    rules[idx+1] = tmp
                    RefreshRulesList()
                    self:OnSettingsChanged()
                end)
                
                yOffset = yOffset + 30
            end
        end
        rightChild:SetHeight(yOffset)
    end
    
    RefreshRulesList()
    return rightColumn
end
