-- GemsTab.lua for EquipOptimizer
local _, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

-- Background tooltip scanner to dynamically detect unique-equipped gems
local tooltipScanner = CreateFrame("GameTooltip", "EquipOptimizerTooltipScanner", nil, "GameTooltipTemplate")
tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local function IsItemUniqueEquipped(itemId)
    local _, _, gemData = ItemEvaluator:FindGemInDB(itemId)
    if gemData and gemData.isMeta then
        return true
    end
    return false
end

local function SetupTooltip(btn, link)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end



function UI:DrawGems()
    local gemsContainer = self.mainWindow.gemsContainer
    self:ClearContainer(gemsContainer)
    
    local title = gemsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", gemsContainer, "TOPLEFT", 10, -10)
    title:SetText(L.GEMS or "Gems")
    
    -- Dropdown for Gem Quality
    local qualityDropdown = self:CreateDropdown(gemsContainer, 160, L.GEM_QUALITY or "Качество камней")
    qualityDropdown:SetPoint("TOPRIGHT", gemsContainer, "TOPRIGHT", -10, -10)
    
    local function GetRankTextWithIcon(rank)
        local baseText = L["GEM_RANK_" .. rank] or ("Rank " .. rank)
        -- Rare gems use chat quality icons for 2-tier items: 12-tier1 (silver diamond) and 12-tier2 (gold pentagon)
        local atlasName = "professions-chaticon-quality-12-tier" .. rank
        return string.format("%s |A:%s:16:16:0:0|a", baseText, atlasName)
    end
    
    local options = {
        [1] = GetRankTextWithIcon(1),
        [2] = GetRankTextWithIcon(2),
    }
    local chosenQuality = Core.activeProfile.gemQuality or 2
    qualityDropdown.text:SetText(options[chosenQuality] or options[2])
    
    qualityDropdown:SetScript("OnClick", function()
        self:OpenDropdownMenu(qualityDropdown, options, Core.activeProfile.gemQuality or 2, function(key)
            Core.activeProfile.gemQuality = key
            qualityDropdown.text:SetText(options[key])
            self:Refresh() -- Refresh UI to update recommendations immediately
        end)
    end)
    
    -- Dropdown for Meta Gem Preference
    local metaDropdown = self:CreateDropdown(gemsContainer, 200, L.META_GEM_PREF or "Выбор мета-камня")
    metaDropdown:SetPoint("TOPRIGHT", qualityDropdown, "TOPLEFT", -20, 0)
    
    local metaOptions = {
        [0] = L.META_AUTO or "Автоматически"
    }
    
    local fallbacks = {
        [1] = "Могучий алмаз",
        [2] = "Теллурический алмаз",
        [3] = "Стоический алмаз",
        [4] = "Непостижимый алмаз"
    }
    
    local function UpdateMetaOptions()
        local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
        for f = 1, 4 do
            local gemId = ItemEvaluator.GemDB[f].ids[2]
            local name = GetItemInfo(gemId)
            if name then
                name = name:gsub(" Вечной Песни", ""):gsub(" Eversong Diamond", "")
                metaOptions[f] = name
            else
                metaOptions[f] = fallbacks[f]
            end
        end
    end
    UpdateMetaOptions()
    
    local chosenMeta = Core.activeProfile.metaGemPreference or 0
    metaDropdown.text:SetText(metaOptions[chosenMeta] or metaOptions[0])
    
    metaDropdown:SetScript("OnClick", function()
        UpdateMetaOptions()
        self:OpenDropdownMenu(metaDropdown, metaOptions, Core.activeProfile.metaGemPreference or 0, function(key)
            Core.activeProfile.metaGemPreference = key
            metaDropdown.text:SetText(metaOptions[key])
            self:Refresh()
        end)
    end)
    
    local gems, equippedSockets, recommendedSockets = ItemEvaluator:GetSocketRecommendations()
    
    -- Cache unique flags for evaluated gems
    for _, g in ipairs(gems) do
        g.isUnique = IsItemUniqueEquipped(g.id)
    end
    
    -- 1. Left Panel: Best Gems
    local leftPanel = self:CreateBackdropFrame(gemsContainer, L.BEST_GEMS or "Best Gems")
    leftPanel:SetSize(390, 440)
    leftPanel:SetPoint("TOPLEFT", gemsContainer, "TOPLEFT", 0, -55)
    
    local leftScroll, leftChild = self:CreateScrollFrame(leftPanel, 390, 416)
    leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -12)
    
    local leftOffsetY = 0
    for _, g in ipairs(gems) do
        local row = CreateFrame("Frame", nil, leftChild)
        row:SetSize(350, 36)
        row:SetPoint("TOPLEFT", leftChild, "TOPLEFT", 0, -leftOffsetY)
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetTexture(g.icon)
        icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        
        -- Border for icon
        local border = row:CreateTexture(nil, "OVERLAY")
        border:SetSize(26, 26)
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:SetPoint("CENTER", icon, "CENTER", 0, 0)
        
        local lblName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lblName:SetPoint("LEFT", icon, "RIGHT", 8, 5)
        lblName:SetText(g.link)
        lblName:SetWidth(200)
        lblName:SetJustifyH("LEFT")
        
        local frameTip = CreateFrame("Button", nil, row)
        frameTip:SetAllPoints(lblName)
        SetupTooltip(frameTip, g.link)
        
        -- Formulate stats text in descending order of their values
        local statParts = {}
        local statList = {}
        local activePrimary = ItemEvaluator:GetActivePrimaryStat()
        local allKeys = { "STAT_HASTE", "STAT_CRIT", "STAT_MASTERY", "STAT_VERSATILITY", "STAT_STAMINA", "STAT_ARMOR", activePrimary }
        local seenKeys = {}
        for _, statKey in ipairs(allKeys) do
            if not seenKeys[statKey] then
                seenKeys[statKey] = true
                local val = g.stats[statKey] or 0
                if val > 0 then
                    table.insert(statList, { key = statKey, val = val })
                end
            end
        end
        
        table.sort(statList, function(a, b)
            return a.val > b.val
        end)
        
        for _, entry in ipairs(statList) do
            local label = L[entry.key] or entry.key
            label = label:gsub(" ?%(%%%)", "")
            table.insert(statParts, "+" .. entry.val .. " " .. label)
        end
        
        local lblStats = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblStats:SetPoint("LEFT", icon, "RIGHT", 8, -8)
        lblStats:SetText(table.concat(statParts, ", "))
        lblStats:SetTextColor(0.7, 0.7, 0.7)
        lblStats:SetWidth(200)
        lblStats:SetJustifyH("LEFT")
        
        -- Display Unique flag and Score
        local lblScore = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lblScore:SetPoint("RIGHT", row, "RIGHT", -5, 5)
        lblScore:SetText("|cff00ff00" .. math.floor(g.score) .. "|r")
        lblScore:SetJustifyH("RIGHT")
        
        if g.isUnique then
            local lblUnique = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lblUnique:SetPoint("RIGHT", row, "RIGHT", -5, -8)
            lblUnique:SetText("|cffff3333[" .. (L.UNIQUE_GEM or "Unique") .. "]|r")
            lblUnique:SetJustifyH("RIGHT")
        end
        
        leftOffsetY = leftOffsetY + 38
    end
    leftChild:SetHeight(leftOffsetY)
    
    self:RenderSocketLists(gemsContainer, equippedSockets, recommendedSockets, gems)
end
