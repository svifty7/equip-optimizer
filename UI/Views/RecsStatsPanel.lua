-- RecsStatsPanel.lua for EquipOptimizer
local _, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

function UI:DrawRecsStatsPanels(recsContainer, predictedStats)
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
end
