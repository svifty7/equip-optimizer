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
        GameTooltip:AddLine(L.HELP_TOOLTIP_TITLE or "Как настраивать характеристики:", 1, 0.82, 0)
        GameTooltip:AddLine(L.HELP_TOOLTIP_MIN or "", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(L.HELP_TOOLTIP_MAX or "", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(L.HELP_TOOLTIP_ORDER or "", 0.9, 0.9, 0.9, true)
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
                
                local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
                cb:SetPoint("LEFT", row, "LEFT", 0, 0)
                cb:SetChecked(rule.enabled)
                
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
                
                local displayText = baseText
                if isPercent then
                    local cleanText = baseText:gsub(" ?%(%%%)", "")
                    displayText = string.format("%s (%.2f%% / %d)", cleanText, currentPct, currentVal)
                end
                
                local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                lbl:SetPoint("LEFT", row, "LEFT", 30, 0)
                lbl:SetText(displayText)
                lbl:SetWidth(165)
                lbl:SetJustifyH("LEFT")
                
                local ddOp = self:CreateDropdown(row, 65, "")
                ddOp:SetPoint("LEFT", row, "LEFT", 200, 0)
                
                local displayOp = rule.op or "MAX"
                ddOp.text:SetText(displayOp)
                
                local valFrame, valEB = self:CreateEditBox(row, 45, 20, "")
                valFrame:SetPoint("LEFT", ddOp, "RIGHT", 5, 0)
                valEB:SetText(tostring(rule.value or 0))
                
                local function UpdateValueState()
                    local op = rule.op or "MAX"
                    if op == "MAX" then
                        valEB:SetEnabled(false)
                        valEB:SetTextColor(0.4, 0.4, 0.4, 1)
                        valEB:SetText("0")
                    else
                        valEB:SetEnabled(true)
                        valEB:SetTextColor(1, 1, 1, 1)
                        valEB:SetText(tostring(rule.value or 0))
                    end
                end
                UpdateValueState()
                
                local function UpdateRowState()
                    if not cb:GetChecked() then
                        ddOp:Disable()
                        ddOp:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
                        ddOp.text:SetTextColor(0.4, 0.4, 0.4, 1)
                        valEB:SetEnabled(false)
                        valEB:SetTextColor(0.4, 0.4, 0.4, 1)
                    else
                        ddOp:Enable()
                        ddOp:SetBackdropColor(0, 0, 0, 0.6)
                        ddOp.text:SetTextColor(1, 0.82, 0, 1)
                        UpdateValueState()
                    end
                end
                UpdateRowState()
                
                local btnUp = CreateFrame("Button", nil, row)
                btnUp:SetSize(22, 22)
                btnUp:SetPoint("LEFT", valFrame, "RIGHT", 5, 0)
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
                btnDown:SetPoint("LEFT", btnUp, "RIGHT", 2, 0)
                btnDown:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
                btnDown:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
                btnDown:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
                btnDown:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                
                local disableDown = (idx == #rules) or (IsTertiaryStat(rules[idx+1].stat) ~= isTert)
                if disableDown then
                    btnDown:Disable()
                end
                
                cb:SetScript("OnClick", function(selfCb)
                    rule.enabled = selfCb:GetChecked()
                    UpdateRowState()
                    self:OnSettingsChanged()
                end)
                
                ddOp:SetScript("OnClick", function()
                    local opList = {
                        [">="] = "Минимум (%)",
                        ["MAX"] = "Максимизировать"
                    }
                    self:OpenDropdownMenu(ddOp, opList, rule.op or "MAX", function(key)
                        rule.op = key
                        ddOp.text:SetText(key)
                        UpdateValueState()
                        self:OnSettingsChanged()
                    end)
                end)
                
                valEB:SetScript("OnEnterPressed", function(selfEb)
                    rule.value = tonumber(selfEb:GetText()) or 0
                    selfEb:ClearFocus()
                    self:OnSettingsChanged()
                end)
                valEB:SetScript("OnEditFocusLost", function(selfEb)
                    rule.value = tonumber(selfEb:GetText()) or 0
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
