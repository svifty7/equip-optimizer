-- GemsTab.lua for EquipOptimizer
local addonName, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

-- Background tooltip scanner to dynamically detect unique-equipped gems
local tooltipScanner = CreateFrame("GameTooltip", "EquipOptimizerTooltipScanner", nil, "GameTooltipTemplate")
tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local function IsItemUniqueEquipped(itemId)
    tooltipScanner:ClearLines()
    tooltipScanner:SetHyperlink("item:" .. itemId)
    local numLines = tooltipScanner:NumLines() or 0
    for i = 1, numLines do
        local fontString = _G["EquipOptimizerTooltipScannerTextLeft" .. i]
        local text = fontString and fontString:GetText()
        if text then
            local lowerText = text:lower()
            if lowerText:find("unique") or lowerText:find("уникаль") or lowerText:find("ограничение") then
                return true
            end
        end
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

local function SetupItemTooltip(btn, link, item)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if item then
            if item.equippedSlot then
                GameTooltip:SetInventoryItem("player", item.equippedSlot)
            elseif item.bag and item.slot then
                GameTooltip:SetBagItem(item.bag, item.slot)
            else
                GameTooltip:SetHyperlink(link)
            end
        else
            GameTooltip:SetHyperlink(link)
        end
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
        local infoText = ""
        if g.isUnique then
            infoText = "|cffff3333[" .. (L.UNIQUE_GEM or "Unique") .. "]|r "
        end
        
        local lblScore = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lblScore:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        lblScore:SetText(infoText .. "|cff00ff00" .. math.floor(g.score / 1000) .. "|r")
        lblScore:SetJustifyH("RIGHT")
        
        leftOffsetY = leftOffsetY + 38
    end
    leftChild:SetHeight(leftOffsetY)
    
    -- 2. Equipped Gear Panel (Top-Right)
    local equippedPanel = self:CreateBackdropFrame(gemsContainer, L.GEMS_EQUIPPED_TITLE or "Equipped Gear")
    equippedPanel:SetSize(400, 215)
    equippedPanel:SetPoint("TOPLEFT", gemsContainer, "TOPLEFT", 410, -55)
    
    local equippedScroll, equippedChild = self:CreateScrollFrame(equippedPanel, 400, 191)
    equippedScroll:SetPoint("TOPLEFT", equippedPanel, "TOPLEFT", 10, -12)
    
    -- 3. Recommended Gear Panel (Bottom-Right)
    local recommendedPanel = self:CreateBackdropFrame(gemsContainer, L.GEMS_RECOMMENDED_TITLE or "Recommended Gear")
    recommendedPanel:SetSize(400, 215)
    recommendedPanel:SetPoint("TOPLEFT", gemsContainer, "TOPLEFT", 410, -280)
    
    local recommendedScroll, recommendedChild = self:CreateScrollFrame(recommendedPanel, 400, 191)
    recommendedScroll:SetPoint("TOPLEFT", recommendedPanel, "TOPLEFT", 10, -12)
    
    -- Track unique gems already equipped to avoid recommending duplicate uniques
    local function ScanUniques(itemsList)
        local uniques = {}
        local hasMeta = false
        for _, item in ipairs(itemsList) do
            for _, gemId in ipairs(item.filledGems) do
                if gemId > 0 then
                    if IsItemUniqueEquipped(gemId) then
                        uniques[gemId] = true
                    end
                    local _, _, gemData = ItemEvaluator:FindGemInDB(gemId)
                    if gemData and gemData.isMeta then
                        hasMeta = true
                    end
                end
            end
        end
        return uniques, hasMeta
    end
    
    -- Recommender function based on available gems, unique status and meta preference
    local function GetRecommendedGemForSocket(currentGemId, activeUniques, hasMetaGemState)
        local isCurrentMeta = false
        if currentGemId and currentGemId > 0 then
            local _, _, gemData = ItemEvaluator:FindGemInDB(currentGemId)
            if gemData and gemData.isMeta then
                isCurrentMeta = true
            end
        end
        
        local mustBeNormal = hasMetaGemState.hasMeta and not isCurrentMeta
        local chosenMetaFamily = Core.activeProfile.metaGemPreference or 0
        
        for _, g in ipairs(gems) do
            local _, _, gemData = ItemEvaluator:FindGemInDB(g.id)
            local isGemMeta = gemData and gemData.isMeta
            
            if isGemMeta then
                if chosenMetaFamily > 0 and g.family ~= chosenMetaFamily then
                    -- Skip other meta gems
                elseif not mustBeNormal and not activeUniques[g.id] then
                    activeUniques[g.id] = true
                    hasMetaGemState.hasMeta = true
                    return g
                end
            else
                if g.isUnique then
                    if not activeUniques[g.id] then
                        activeUniques[g.id] = true
                        return g
                    end
                else
                    return g
                end
            end
        end
        
        -- Fallback to the best non-meta gem if all meta gems were skipped
        for _, g in ipairs(gems) do
            local _, _, gemData = ItemEvaluator:FindGemInDB(g.id)
            local isGemMeta = gemData and gemData.isMeta
            if not isGemMeta then
                if g.isUnique then
                    if not activeUniques[g.id] then
                        activeUniques[g.id] = true
                        return g
                    end
                else
                    return g
                end
            end
        end
        
        return gems[1]
    end
    
    local GetItemInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    
    local function RenderSocketList(parentChild, itemsList)
        local activeUniques, hasMeta = ScanUniques(itemsList)
        local hasMetaGemState = { hasMeta = hasMeta }
        local offset = 0
        if #itemsList == 0 then
            local noSockets = parentChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            noSockets:SetPoint("TOPLEFT", parentChild, "TOPLEFT", 10, -10)
            noSockets:SetText("|cff888888" .. (L.NO_SOCKETS or "No items with sockets!") .. "|r")
            parentChild:SetHeight(30)
            return
        end
        
        for _, item in ipairs(itemsList) do
            local itemRow = CreateFrame("Frame", nil, parentChild)
            itemRow:SetPoint("TOPLEFT", parentChild, "TOPLEFT", 0, -offset)
            
            local lblItem = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lblItem:SetPoint("TOPLEFT", itemRow, "TOPLEFT", 5, -2)
            lblItem:SetText(item.link)
            lblItem:SetJustifyH("LEFT")
            
            local frameTip = CreateFrame("Button", nil, itemRow)
            frameTip:SetAllPoints(lblItem)
            SetupItemTooltip(frameTip, item.link, item)
            
            local itemOffsetY = 22
            
            for i = 1, item.totalSockets do
                local socketRow = CreateFrame("Frame", nil, itemRow)
                socketRow:SetSize(360, 24)
                socketRow:SetPoint("TOPLEFT", itemRow, "TOPLEFT", 15, -itemOffsetY)
                
                local lblSocketIdx = socketRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                lblSocketIdx:SetPoint("LEFT", socketRow, "LEFT", 0, 0)
                lblSocketIdx:SetText(string.format("|cffeedd88%s %d:|r", L.SOCKET or "Socket", i))
                lblSocketIdx:SetWidth(65)
                lblSocketIdx:SetJustifyH("LEFT")
                
                local currentGemId = item.filledGems[i]
                local currentGemInfo = nil
                
                if currentGemId and currentGemId > 0 then
                    local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(currentGemId)
                    currentGemInfo = {
                        id = currentGemId,
                        link = link or ("item:" .. currentGemId),
                        icon = icon or 134400,
                        score = ItemEvaluator:ScoreGemStats(ItemEvaluator:GetGemStats(currentGemId), Core.activeProfile.rules or {})
                    }
                end
                
                local recGem = GetRecommendedGemForSocket(currentGemId, activeUniques, hasMetaGemState)
                
                local lblCurrent = socketRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                lblCurrent:SetPoint("LEFT", socketRow, "LEFT", 70, 0)
                lblCurrent:SetWidth(125)
                lblCurrent:SetJustifyH("LEFT")
                
                if currentGemInfo then
                    lblCurrent:SetText(currentGemInfo.link)
                    local btnGemTip = CreateFrame("Button", nil, socketRow)
                    btnGemTip:SetAllPoints(lblCurrent)
                    SetupTooltip(btnGemTip, currentGemInfo.link)
                else
                    lblCurrent:SetText("|cff888888[" .. (L.EMPTY or "Empty") .. "]|r")
                end
                
                local lblRec = socketRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                lblRec:SetPoint("LEFT", socketRow, "LEFT", 200, 0)
                lblRec:SetWidth(150)
                lblRec:SetJustifyH("LEFT")
                
                local isOptimal = false
                if currentGemInfo and recGem then
                    local curFamily, curRank, curData = ItemEvaluator:FindGemInDB(currentGemInfo.id)
                    local recFamily, recRank, recData = ItemEvaluator:FindGemInDB(recGem.id)
                    if curFamily and recFamily and curFamily == recFamily then
                        if curRank >= recRank then
                            isOptimal = true
                        end
                    elseif currentGemInfo.id == recGem.id then
                        isOptimal = true
                    end
                end
                
                if isOptimal then
                    lblRec:SetText("|cff00ff00(" .. (L.RECOMMENDED or "Optimal") .. ")|r")
                elseif recGem then
                    lblRec:SetText(string.format("> %s", recGem.link))
                    local btnRecTip = CreateFrame("Button", nil, socketRow)
                    btnRecTip:SetAllPoints(lblRec)
                    SetupTooltip(btnRecTip, recGem.link)
                else
                    lblRec:SetText("")
                end
                
                itemOffsetY = itemOffsetY + 22
            end
            
            itemRow:SetSize(360, itemOffsetY + 5)
            offset = offset + itemOffsetY + 15
        end
        parentChild:SetHeight(offset)
    end
    
    RenderSocketList(equippedChild, equippedSockets)
    RenderSocketList(recommendedChild, recommendedSockets)
end
