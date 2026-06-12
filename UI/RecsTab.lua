-- RecsTab.lua for EquipOptimizer
local _, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

function UI:DrawRecs()
    local recsContainer = self.mainWindow.recsContainer
    self:ClearContainer(recsContainer)
    
    local recs, predictedStats = ItemEvaluator:Optimize()
    
    local title = recsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 10, -10)
    title:SetText(L.RECOMMENDATIONS or "Recommendations")
    
    local recsScroll, recsChild = self:CreateScrollFrame(recsContainer, 803, 250)
    recsScroll:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 10, -40)
    
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
    
    if count == 0 then
        local noRecs = recsChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        noRecs:SetPoint("TOPLEFT", recsChild, "TOPLEFT", 10, -10)
        local rules = Core.activeProfile.rules or {}
        local hasActiveRules = false
        for _, r in ipairs(rules) do
            if r.enabled then hasActiveRules = true; break end
        end
        if not hasActiveRules then
            noRecs:SetText("|cffffff00" .. L.NO_RULES .. "|r")
        else
            noRecs:SetText("|cff00ff00" .. L.NO_RECS .. "|r")
        end
        offsetY = offsetY + 30
    end
    
    recsChild:SetHeight(offsetY)
    
    -- Primary and Secondary Stats Panels
    local primaryPanel = self:CreateBackdropFrame(recsContainer, L.PRIMARY_STATS or "Primary Stats")
    primaryPanel:SetSize(390, 115)
    primaryPanel:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 0, -305)
    
    local secondaryPanel = self:CreateBackdropFrame(recsContainer, L.SECONDARY_STATS or "Secondary Stats")
    secondaryPanel:SetSize(390, 115)
    secondaryPanel:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 400, -305)
    
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
            
            local rating_per_percent = 0
            if statInfo.isPercent then
                rating_per_percent = ItemEvaluator:GetRatingPerPercent(statInfo.ratingIndex or 0)
                local bp = basePct[key] or 0
                currentPct = bp + (rating_per_percent > 0 and (currentVal / rating_per_percent) or 0)
            end

            
            local predictedVal = predictedStats[key] or currentVal
            local diffRating = predictedVal - currentVal
            
            local valStr, diffStr = "", ""
            local cleanLabel = statInfo.label
            
            if statInfo.isPercent then
                cleanLabel = statInfo.label:gsub(" ?%(%%%)", "")
                local bp = basePct[key] or 0
                local predictedPct = bp + (rating_per_percent > 0 and (predictedVal / rating_per_percent) or 0)
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
                -- Primary stats / Stamina / Armor
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
    
    -- Equip Button
    local equipBtn = self:CreateStyledButton(recsContainer, 790, 35, L.EQUIP_BEST or "Equip Best")
    equipBtn:SetPoint("TOPLEFT", primaryPanel, "BOTTOMLEFT", 0, -15)
    
    local function UpdateButtonState()
        if InCombatLockdown() then
            self:SetButtonDisabled(equipBtn, true)
            equipBtn.text:SetText(L.IN_COMBAT or "In Combat")
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
