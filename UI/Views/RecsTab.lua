-- RecsTab.lua for EquipOptimizer
local _, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

function UI:RefreshProgress()
    if not self:IsWindowOpen() then return end
    
    local recsContainer = self.mainWindow.recsContainer
    if self.mainWindow.selectedTab == "recs" and ItemEvaluator.isOptimizing then
        if recsContainer.title then
            local titleText = L.RECOMMENDATIONS or "Recommendations"
            local analyzedStr = string.format(L.ANALYZED_COMBINATIONS or "Analyzed: %d", ItemEvaluator.analyzedCombinations or 0)
            recsContainer.title:SetText(string.format("%s (Расчет: %d%%, %s)", titleText, ItemEvaluator.optimizationProgress, analyzedStr))
        end
        if recsContainer.equipBtn then
            self:SetButtonDisabled(recsContainer.equipBtn, true)
            recsContainer.equipBtn.text:SetText(string.format("Оптимизация... (%d%%)", ItemEvaluator.optimizationProgress))
        end
        if recsContainer.reanalyzeBtn then
            self:SetButtonDisabled(recsContainer.reanalyzeBtn, true)
        end
    end
end

function UI:DrawRecs()
    local recsContainer = self.mainWindow.recsContainer
    
    -- 1. Create main title once
    if not recsContainer.title then
        recsContainer.title = recsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        recsContainer.title:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 10, -10)
    end
    recsContainer.title:Show()
    recsContainer.progressText = recsContainer.title
    
    -- Create reanalyze button once
    if not recsContainer.reanalyzeBtn then
        local btn = self:CreateStyledButton(recsContainer, 110, 22, L.REANALYZE or "Recalculate")
        btn:SetPoint("TOPRIGHT", recsContainer, "TOPRIGHT", -10, -8)
        btn:SetScript("OnClick", function()
            ItemEvaluator:StartOptimize(true)
            self:Refresh()
        end)
        recsContainer.reanalyzeBtn = btn
    end
    recsContainer.reanalyzeBtn:Show()
    if ItemEvaluator.isOptimizing or ItemEvaluator:IsEquipQueueActive() then
        self:SetButtonDisabled(recsContainer.reanalyzeBtn, true)
    else
        self:SetButtonDisabled(recsContainer.reanalyzeBtn, false)
    end
    
    -- 2. Create scroll frame once
    if not recsContainer.recsScroll then
        local scroll, child = self:CreateScrollFrame(recsContainer, 803, 250)
        scroll:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 10, -40)
        recsContainer.recsScroll = scroll
        recsContainer.recsChild = child
    end
    recsContainer.recsScroll:Show()
    local recsChild = recsContainer.recsChild
    
    -- Clear dynamic rows inside child scroll
    self:ClearContainer(recsChild)
    
    local recs, predictedStats = ItemEvaluator:Optimize()
    
    -- Update title
    local titleText = L.RECOMMENDATIONS or "Recommendations"
    if ItemEvaluator.isOptimizing then
        local analyzedStr = string.format(L.ANALYZED_COMBINATIONS or "Analyzed: %d", ItemEvaluator.analyzedCombinations or 0)
        titleText = string.format("%s (Расчет: %d%%, %s)", titleText, ItemEvaluator.optimizationProgress, analyzedStr)
    elseif ItemEvaluator.hasOptimizationRun and (ItemEvaluator.analyzedCombinations or 0) > 0 then
        local analyzedStr = string.format(L.ANALYZED_COMBINATIONS or "Analyzed: %d", ItemEvaluator.analyzedCombinations or 0)
        titleText = string.format("%s (%s)", titleText, analyzedStr)
    end
    recsContainer.title:SetText(titleText)
    
    local offsetY = 0
    local count = 0
    
    for _, slotInfo in ipairs(Core.Slots) do
        local slotId = slotInfo.id
        local rec = recs[slotId]
        
        if rec then
            count = count + 1
            local row = CreateFrame("Frame", nil, recsChild)
            row:SetSize(760, 26)
            row:SetPoint("TOPLEFT", recsChild, "TOPLEFT", 0, -offsetY)
            
            local lblSlot = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lblSlot:SetPoint("LEFT", row, "LEFT", 0, 0)
            lblSlot:SetText(string.format("|cffeedd88%s:|r", L[slotInfo.label] or slotInfo.name))
            lblSlot:SetWidth(120)
            lblSlot:SetJustifyH("LEFT")
            
            local lblCurrent = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lblCurrent:SetPoint("LEFT", row, "LEFT", 130, 0)
            lblCurrent:SetText(rec.currentLink or ("|cff888888" .. (L.EMPTY or "Empty") .. "|r"))
            lblCurrent:SetWidth(240)
            lblCurrent:SetJustifyH("LEFT")
            
            local lblArrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lblArrow:SetPoint("LEFT", row, "LEFT", 380, 0)
            lblArrow:SetText(">")
            lblArrow:SetWidth(30)
            
            local lblRec = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lblRec:SetPoint("LEFT", row, "LEFT", 420, 0)
            lblRec:SetText(rec.recommendedLink or ("|cff888888" .. (L.EMPTY or "Empty") .. "|r"))
            lblRec:SetWidth(240)
            lblRec:SetJustifyH("LEFT")
            
            local lblDiff = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lblDiff:SetPoint("LEFT", row, "LEFT", 670, 0)
            
            local diffText = ""
            if rec.ilvlDiff > 0 then
                diffText = string.format("|cff00ff00+%d ilvl|r", rec.ilvlDiff)
            elseif rec.ilvlDiff < 0 then
                diffText = string.format("|cffff0000%d ilvl|r", rec.ilvlDiff)
            else
                diffText = "|cff8888880 ilvl|r"
            end
            lblDiff:SetText(diffText)
            lblDiff:SetWidth(80)
            lblDiff:SetJustifyH("RIGHT")
            
            local function CreateTooltipArea(strString, itemLink, isCurrent)
                if not itemLink then return end
                local frameTip = CreateFrame("Button", nil, row)
                frameTip:SetAllPoints(strString)
                frameTip:SetScript("OnEnter", function(selfTip)
                    GameTooltip:SetOwner(selfTip, "ANCHOR_RIGHT")
                    if isCurrent then
                        GameTooltip:SetInventoryItem("player", slotId)
                    elseif rec.equippedSlot then
                        GameTooltip:SetInventoryItem("player", rec.equippedSlot)
                    elseif rec.bag and rec.slot then
                        GameTooltip:SetBagItem(rec.bag, rec.slot)
                    else
                        GameTooltip:SetHyperlink(itemLink)
                    end
                    GameTooltip:Show()
                end)
                frameTip:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end
            CreateTooltipArea(lblCurrent, rec.currentLink, true)
            CreateTooltipArea(lblRec, rec.recommendedLink, false)
            
            offsetY = offsetY + 28
        end
    end
    
    if count == 0 and not ItemEvaluator.isOptimizing then
        if not recsContainer.noRecsText then
            recsContainer.noRecsText = recsChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            recsContainer.noRecsText:SetPoint("TOPLEFT", recsChild, "TOPLEFT", 10, -10)
        end
        recsContainer.noRecsText:Show()
        local rules = Core.activeProfile.rules or {}
        local hasActiveRules = false
        for _, r in ipairs(rules) do
            if r.enabled then hasActiveRules = true; break end
        end
        if not hasActiveRules then
            recsContainer.noRecsText:SetText("|cffffff00" .. L.NO_RULES .. "|r")
        else
            recsContainer.noRecsText:SetText("|cff00ff00" .. L.NO_RECS .. "|r")
        end
        offsetY = offsetY + 30
    else
        if recsContainer.noRecsText then
            recsContainer.noRecsText:Hide()
        end
    end
    
    recsChild:SetHeight(offsetY)
    
    self:DrawRecsStatsPanels(recsContainer, predictedStats)
    
    -- 4. Create equipBtn once
    if not recsContainer.equipBtn then
        local equipBtn = self:CreateStyledButton(recsContainer, 790, 35, L.EQUIP_BEST or "Equip Best")
        equipBtn:SetPoint("TOPLEFT", recsContainer.primaryPanel, "BOTTOMLEFT", 0, -15)
        recsContainer.equipBtn = equipBtn
    end
    recsContainer.equipBtn:Show()
    local equipBtn = recsContainer.equipBtn
    
    local function UpdateButtonState()
        if InCombatLockdown() then
            self:SetButtonDisabled(equipBtn, true)
            equipBtn.text:SetText(L.IN_COMBAT or "In Combat")
        elseif ItemEvaluator.isOptimizing then
            self:SetButtonDisabled(equipBtn, true)
            equipBtn.text:SetText(string.format("Оптимизация... (%d%%)", ItemEvaluator.optimizationProgress))
        elseif ItemEvaluator:IsEquipQueueActive() then
            self:SetButtonDisabled(equipBtn, true)
            equipBtn.text:SetText(L.EQUIPPING or "Equipping...")
        else
            local hasRecs = false
            for _ in pairs(recs) do
                hasRecs = true
                break
            end
            self:SetButtonDisabled(equipBtn, not hasRecs)
            equipBtn.text:SetText(L.EQUIP_BEST or "Equip Best")
        end
    end
    
    UpdateButtonState()
    equipBtn:SetScript("OnClick", function()
        ItemEvaluator:EquipRecommended(recs)
        UpdateButtonState()
    end)
end
