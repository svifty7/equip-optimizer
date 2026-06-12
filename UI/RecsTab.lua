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
    
    -- 3. Create panels once
    if not recsContainer.primaryPanel then
        recsContainer.primaryPanel = self:CreateBackdropFrame(recsContainer, L.PRIMARY_STATS or "Primary Stats")
        recsContainer.primaryPanel:SetSize(390, 115)
        recsContainer.primaryPanel:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 0, -305)
    end
    recsContainer.primaryPanel:Show()
    local primaryPanel = recsContainer.primaryPanel
    
    if not recsContainer.secondaryPanel then
        recsContainer.secondaryPanel = self:CreateBackdropFrame(recsContainer, L.SECONDARY_STATS or "Secondary Stats")
        recsContainer.secondaryPanel:SetSize(390, 115)
        recsContainer.secondaryPanel:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 400, -305)
    end
    recsContainer.secondaryPanel:Show()
    local secondaryPanel = recsContainer.secondaryPanel
    
    -- Hide old stat FontStrings from panels to redraw fresh ones without overlapping
    local primRegions = { primaryPanel:GetRegions() }
    for _, reg in ipairs(primRegions) do
        if reg ~= primaryPanel.Title then reg:Hide() end
    end
    local secRegions = { secondaryPanel:GetRegions() }
    for _, reg in ipairs(secRegions) do
        if reg ~= secondaryPanel.Title then reg:Hide() end
    end
    
    local activePrimaryStat = "STAT_INTELLECT"
    local spec = GetSpecialization()
    if spec and spec > 0 then
        local _, _, _, _, _, primaryStat = GetSpecializationInfo(spec)
        if primaryStat == 1 then
            activePrimaryStat = "STAT_STRENGTH"
        elseif primaryStat == 2 then
            activePrimaryStat = "STAT_AGILITY"
        elseif primaryStat == 4 then
            activePrimaryStat = "STAT_INTELLECT"
        end
    else
        local _, class = UnitClass("player")
        if class == "WARRIOR" or class == "PALADIN" or class == "DEATHKNIGHT" then
            activePrimaryStat = "STAT_STRENGTH"
        elseif class == "ROGUE" or class == "HUNTER" or class == "DEMONHUNTER" or class == "MONK" or class == "DRUID" then
            activePrimaryStat = "STAT_AGILITY"
        end
    end

    local primaryStatsToShow = {
        { key = "STAT_ILVL", label = L.STAT_ILVL, isPercent = false },
        { key = "STAT_ARMOR", label = L.STAT_ARMOR or "Armor", isPercent = false },
    }

    if activePrimaryStat == "STAT_STRENGTH" then
        table.insert(primaryStatsToShow, { key = "STAT_STRENGTH", label = L.STAT_STRENGTH or "Strength", isPercent = false })
    elseif activePrimaryStat == "STAT_AGILITY" then
        table.insert(primaryStatsToShow, { key = "STAT_AGILITY", label = L.STAT_AGILITY or "Agility", isPercent = false })
    else
        table.insert(primaryStatsToShow, { key = "STAT_INTELLECT", label = L.STAT_INTELLECT or "Intellect", isPercent = false })
    end

    table.insert(primaryStatsToShow, { key = "STAT_STAMINA", label = L.STAT_STAMINA or "Stamina", isPercent = false })
    
    local secondaryStatsToShow = {
        { key = "STAT_HASTE", label = L.STAT_HASTE, isPercent = true, ratingIndex = ItemEvaluator.CR_HASTE },
        { key = "STAT_CRIT", label = L.STAT_CRIT, isPercent = true, ratingIndex = ItemEvaluator.CR_CRIT },
        { key = "STAT_MASTERY", label = L.STAT_MASTERY, isPercent = true, ratingIndex = ItemEvaluator.CR_MASTERY },
        { key = "STAT_VERSATILITY", label = L.STAT_VERSATILITY, isPercent = true, ratingIndex = ItemEvaluator.CR_VERSATILITY },
    }
    
    local function RenderPanelStats(panel, statsList, startY, rowHeight)
        local offsetY = startY
        local currentStats = ItemEvaluator:GetPlayerCurrentStats()
        local basePct = ItemEvaluator:GetBaseStatPercentages()
        for _, statInfo in ipairs(statsList) do
            local key = statInfo.key
            local currentVal = currentStats[key] or 0
            local currentPct = 0
            
            if statInfo.isPercent then
                local bp = basePct[key] or 0
                currentPct = bp + ItemEvaluator:ConvertRatingToPercent(key, currentVal)
            end

            local predictedVal = predictedStats[key] or currentVal
            local diffRating = predictedVal - currentVal
            
            local valStr, diffStr = "", ""
            local cleanLabel = statInfo.label
            
            if statInfo.isPercent then
                cleanLabel = statInfo.label:gsub(" ?%(%%%)", "")
                local bp = basePct[key] or 0
                local predictedPct = bp + ItemEvaluator:ConvertRatingToPercent(key, predictedVal)
                local diffPct = predictedPct - currentPct
                
                valStr = string.format("%.2f%% (%d)", predictedPct, predictedVal)
                if diffRating > 0.05 then
                    diffStr = string.format(" (|cff00ff00+%.2f%% / +%d|r)", diffPct, diffRating)
                elseif diffRating < -0.05 then
                    diffStr = string.format(" (|cffff0000%.2f%% / %d|r)", diffPct, diffRating)
                end
            elseif key == "STAT_ILVL" then
                valStr = string.format("%.1f", predictedVal)
                if diffRating > 0.05 then
                    diffStr = string.format(" (|cff00ff00+%.1f|r)", diffRating)
                elseif diffRating < -0.05 then
                    diffStr = string.format(" (|cffff0000%.1f|r)", diffRating)
                end
            else
                valStr = string.format("%d", predictedVal)
                if diffRating > 0 then
                    diffStr = string.format(" (|cff00ff00+%d|r)", diffRating)
                elseif diffRating < 0 then
                    diffStr = string.format(" (|cffff0000%d|r)", diffRating)
                end
            end
            
            local lblStatValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lblStatValue:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -15, offsetY)
            lblStatValue:SetText(string.format("%s%s", valStr, diffStr))
            lblStatValue:SetJustifyH("RIGHT")
 
            local lblStatLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lblStatLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, offsetY)
            lblStatLabel:SetPoint("RIGHT", lblStatValue, "LEFT", -10, 0)
            lblStatLabel:SetText(cleanLabel)
            lblStatLabel:SetJustifyH("LEFT")
            
            offsetY = offsetY - rowHeight
        end
    end
    
    RenderPanelStats(primaryPanel, primaryStatsToShow, -10, 28)
    RenderPanelStats(secondaryPanel, secondaryStatsToShow, -10, 28)
    
    -- 4. Create equipBtn once
    if not recsContainer.equipBtn then
        local equipBtn = self:CreateStyledButton(recsContainer, 790, 35, L.EQUIP_BEST or "Equip Best")
        equipBtn:SetPoint("TOPLEFT", primaryPanel, "BOTTOMLEFT", 0, -15)
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
