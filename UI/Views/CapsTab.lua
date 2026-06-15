-- CapsTab.lua for EquipOptimizer
local _, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

local function SetupTooltip(btn, link, slotId)
    if not link then return end
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if slotId then
            GameTooltip:SetInventoryItem("player", slotId)
        else
            GameTooltip:SetHyperlink(link)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function UI:DrawCapsRow(parent, slotInfo, offsetY)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(760, 24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -offsetY)
    
    local lblSlot = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblSlot:SetPoint("LEFT", row, "LEFT", 10, 0)
    lblSlot:SetText(string.format("|cffeedd88%s:|r", slotInfo.slotName))
    lblSlot:SetWidth(110)
    lblSlot:SetJustifyH("LEFT")
    
    local lblEquipped = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblEquipped:SetPoint("LEFT", row, "LEFT", 125, 0)
    lblEquipped:SetText(slotInfo.itemLink or ("|cff888888" .. (L.EMPTY or "Empty") .. "|r"))
    lblEquipped:SetWidth(200)
    lblEquipped:SetJustifyH("LEFT")
    
    local lblAction = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblAction:SetPoint("LEFT", row, "LEFT", 335, 0)
    lblAction:SetWidth(415)
    lblAction:SetJustifyH("LEFT")
    
    lblAction:SetText(string.format(L.ITEM_STATS_FORMAT or "Характеристики: %s", slotInfo.extraStatsString))
    
    local btnEq = CreateFrame("Button", nil, row)
    btnEq:SetAllPoints(lblEquipped)
    SetupTooltip(btnEq, slotInfo.itemLink, slotInfo.slotId)
    
    return row
end

function UI:DrawCaps()
    local capsContainer = self.mainWindow.capsContainer
    self:ClearContainer(capsContainer)
    
    local title = capsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", capsContainer, "TOPLEFT", 10, -10)
    title:SetText(L.CAPS_ANALYSIS or "Soft-Cap Analysis")
    
    local help = capsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", capsContainer, "TOPLEFT", 10, -32)
    help:SetText(L.CAPS_HELP or "This tab shows which equipment slots can theoretically be upgraded to reach your soft-caps.")
    help:SetTextColor(0.6, 0.6, 0.6, 1)
    
    local scroll, child = self:CreateScrollFrame(capsContainer, 803, 440)
    scroll:SetPoint("TOPLEFT", capsContainer, "TOPLEFT", 10, -55)
    
    local result = ItemEvaluator:AnalyzeCaps()
    local offsetY = 5
    
    if #result.unmet == 0 then
        local status = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        status:SetPoint("TOPLEFT", child, "TOPLEFT", 20, -20)
        status:SetText("|cff00ff00" .. (L.NO_CAPS_UNMET or "All soft-caps are successfully met!") .. "|r")
        offsetY = offsetY + 40
    else
        -- 1. Draw unmet caps headers
        local unmetHeader = child:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
        unmetHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -offsetY)
        unmetHeader:SetText(L.UNMET_CAPS_TITLE or "Unmet Soft-Caps:")
        unmetHeader:SetTextColor(1, 0.3, 0.3, 1)
        offsetY = offsetY + 20
        
        for _, item in ipairs(result.unmet) do
            local rule = item.rule
            local target = rule.value or 0
            local base = item.basePercent or 0
            local targetPct = base + ItemEvaluator:ConvertRatingToPercent(rule.stat, target)
            local currentPct = base + ItemEvaluator:ConvertRatingToPercent(rule.stat, item.currentRating)
            local missingPercent = math.max(0, targetPct - currentPct)
            local missingRating = math.max(0, target - item.currentRating)
            
            local lblCap = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lblCap:SetPoint("TOPLEFT", child, "TOPLEFT", 20, -offsetY)
            lblCap:SetText(string.format(L.MISSING_CAP_FORMAT or "%s: missing %.2f%% (%d rating)", 
                L[rule.stat] or rule.stat, missingPercent, math.ceil(missingRating)))
            offsetY = offsetY + 18
        end
        offsetY = offsetY + 15
        
        -- 2. Draw total summary header
        local totalExtraRating = 0
        for _, slot in ipairs(result.slots) do
            if not slot.isLocked and not slot.isSetLocked then
                for _, rating in pairs(slot.extraRatingsTable) do
                    totalExtraRating = totalExtraRating + rating
                end
            end
        end
        
        local summaryText = string.format(L.TOTAL_EXTRA_STATS or "Всего лишних характеристик для замены: %d ед. рейтинга", totalExtraRating)
        local summaryHeader = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        summaryHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -offsetY)
        summaryHeader:SetText(summaryText)
        offsetY = offsetY + 26
        
        -- 3. Draw flat slots list
        table.sort(result.slots, function(a, b)
            return (a.extraRatingSum or 0) > (b.extraRatingSum or 0)
        end)
        
        local count = 0
        for _, slotInfo in ipairs(result.slots) do
            if not slotInfo.isLocked and not slotInfo.isSetLocked and #slotInfo.extraStats > 0 then
                self:DrawCapsRow(child, slotInfo, offsetY)
                offsetY = offsetY + 24
                count = count + 1
            end
        end
        
        if count == 0 then
            local allOptimized = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            allOptimized:SetPoint("TOPLEFT", child, "TOPLEFT", 20, -offsetY)
            allOptimized:SetText("|cff00ff00" .. (L.NO_RECS or "All slots are optimized!") .. "|r")
            offsetY = offsetY + 24
        end
    end
    
    child:SetHeight(offsetY)
end
