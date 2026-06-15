-- GemsRecommender.lua for EquipOptimizer
local _, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local UI = addonTable.UI

-- Helper tooltips
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

local function IsItemUniqueEquipped(itemId)
    local _, _, gemData = ItemEvaluator:FindGemInDB(itemId)
    if gemData and gemData.isMeta then
        return true
    end
    return false
end

-- Render equipped & recommended socket lists panels
function UI:RenderSocketLists(gemsContainer, equippedSockets, recommendedSockets, gems)
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
        local metaCount = 0
        for _, item in ipairs(itemsList) do
            for _, gemId in ipairs(item.filledGems) do
                if gemId > 0 then
                    if IsItemUniqueEquipped(gemId) then
                        uniques[gemId] = (uniques[gemId] or 0) + 1
                    end
                    local _, _, gemData = ItemEvaluator:FindGemInDB(gemId)
                    if gemData and gemData.isMeta then
                        metaCount = metaCount + 1
                    end
                end
            end
        end
        return uniques, metaCount
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
                elseif not mustBeNormal and not (activeUniques[g.id] and activeUniques[g.id] > 0) then
                    activeUniques[g.id] = (activeUniques[g.id] or 0) + 1
                    hasMetaGemState.hasMeta = true
                    return g
                end
            else
                if g.isUnique then
                    if not (activeUniques[g.id] and activeUniques[g.id] > 0) then
                        activeUniques[g.id] = (activeUniques[g.id] or 0) + 1
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
                    if not (activeUniques[g.id] and activeUniques[g.id] > 0) then
                        activeUniques[g.id] = (activeUniques[g.id] or 0) + 1
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
        local activeUniques, metaCount = ScanUniques(itemsList)
        local hasMetaGemState = { hasMeta = (metaCount > 0) }
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
                
                -- Temporarily decrement current gem's equipped status to allow keeping it
                if currentGemId and currentGemId > 0 then
                    if activeUniques[currentGemId] and activeUniques[currentGemId] > 0 then
                        activeUniques[currentGemId] = activeUniques[currentGemId] - 1
                    end
                    local _, _, gemData = ItemEvaluator:FindGemInDB(currentGemId)
                    if gemData and gemData.isMeta then
                        metaCount = metaCount - 1
                        hasMetaGemState.hasMeta = (metaCount > 0)
                    end
                end
                
                local recGem = GetRecommendedGemForSocket(currentGemId, activeUniques, hasMetaGemState)
                
                -- Update meta count after recommendation is made
                if recGem then
                    local _, _, gemData = ItemEvaluator:FindGemInDB(recGem.id)
                    if gemData and gemData.isMeta then
                        metaCount = metaCount + 1
                        hasMetaGemState.hasMeta = (metaCount > 0)
                    end
                end
                
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
