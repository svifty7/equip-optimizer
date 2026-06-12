-- Dropdown.lua for EquipOptimizer
local addonName, addonTable = ...
local Core = addonTable.Core
local UI = addonTable.UI or {}
addonTable.UI = UI
Core.UI = UI

-- Close dropdown on clicking anywhere else
local DropdownMenu = nil
local dropdownButtons = {}

function UI:CloseDropdownMenu()
    if DropdownMenu then
        DropdownMenu:Hide()
        GameTooltip:Hide()
    end
end

local clickDetector = CreateFrame("Frame", nil, UIParent)
clickDetector:SetAllPoints()
clickDetector:Hide()
clickDetector:EnableMouse(true)
clickDetector:SetFrameStrata("TOOLTIP")
clickDetector:SetFrameLevel(999)
clickDetector:SetScript("OnMouseDown", function()
    UI:CloseDropdownMenu()
    clickDetector:Hide()
end)

function UI:OpenDropdownMenu(anchor, options, selectedValue, onSelect)
    if not DropdownMenu then
        DropdownMenu = CreateFrame("Frame", "EquipOptimizerDropdownMenu", UIParent, "BackdropTemplate")
        DropdownMenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        DropdownMenu:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
        DropdownMenu:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
        DropdownMenu:SetFrameStrata("TOOLTIP")
        DropdownMenu:SetFrameLevel(1000)

        local dropdownScroll = CreateFrame("ScrollFrame", nil, DropdownMenu, "UIPanelScrollFrameTemplate")
        dropdownScroll:SetPoint("TOPLEFT", 6, -6)
        dropdownScroll:SetPoint("BOTTOMRIGHT", -22, 6)

        local dropdownChild = CreateFrame("Frame", nil, dropdownScroll)
        dropdownChild:SetWidth(125)
        dropdownChild:SetHeight(1)
        dropdownScroll:SetScrollChild(dropdownChild)
        DropdownMenu.Scroll = dropdownScroll
        DropdownMenu.Child = dropdownChild
    end

    DropdownMenu:ClearAllPoints()
    
    local scale = anchor:GetEffectiveScale()
    local left = anchor:GetLeft()
    local bottom = anchor:GetBottom()
    
    if left and bottom then
        local uiScale = UIParent:GetEffectiveScale()
        local x = left * scale / uiScale
        local y = bottom * scale / uiScale
        DropdownMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y - 2)
    else
        DropdownMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    local ddWidth = math.max(anchor:GetWidth(), 160)
    DropdownMenu:SetWidth(ddWidth)
    
    -- Clear previous buttons
    for _, btn in ipairs(dropdownButtons) do
        btn:Hide()
    end
    
    local width = ddWidth - 28
    DropdownMenu.Child:SetWidth(width)
    
    local offsetY = 0
    local count = 0
    
    local sorted = {}
    for k, v in pairs(options) do
        if type(v) == "table" then
            table.insert(sorted, { key = k, val = v.text, tooltipData = v.tooltipData })
        else
            table.insert(sorted, { key = k, val = v })
        end
    end
    
    table.sort(sorted, function(a, b)
        if a.key == "equipped" then return true end
        if b.key == "equipped" then return false end
        if a.key == 0 or a.key == "none" then return true end
        if b.key == 0 or b.key == "none" then return false end
        local numA = tonumber(a.key)
        local numB = tonumber(b.key)
        if numA and numB then
            return numA < numB
        end
        return tostring(a.val) < tostring(b.val)
    end)
    
    for i, item in ipairs(sorted) do
        count = count + 1
        local btn = dropdownButtons[count]
        if not btn then
            btn = CreateFrame("Button", nil, DropdownMenu.Child)
            btn:SetHeight(20)
            btn:SetNormalFontObject(GameFontHighlightSmall)
            btn:SetHighlightFontObject(GameFontNormalSmall)
            
            local tex = btn:CreateTexture(nil, "HIGHLIGHT")
            tex:SetAllPoints()
            tex:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            
            dropdownButtons[count] = btn
        end
        
        btn:SetWidth(width)
        btn:SetPoint("TOPLEFT", DropdownMenu.Child, "TOPLEFT", 0, -offsetY)
        btn:SetText(item.val)
        btn:GetFontString():SetPoint("LEFT", btn, "LEFT", 5, 0)
        btn:Show()
        
        if item.tooltipData or (item.key and tostring(item.key):find("|Hitem:")) then
            btn:SetScript("OnEnter", function(selfTip)
                GameTooltip:SetOwner(selfTip, "ANCHOR_RIGHT")
                local td = item.tooltipData
                if td then
                    if td.isEquipped and td.slotId then
                        GameTooltip:SetInventoryItem("player", td.slotId)
                    elseif not td.isEquipped and td.bag and td.slot then
                        GameTooltip:SetBagItem(td.bag, td.slot)
                    else
                        GameTooltip:SetHyperlink(item.key)
                    end
                else
                    GameTooltip:SetHyperlink(item.key)
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
        end
        
        if item.key == selectedValue then
            btn:GetFontString():SetTextColor(1, 0.8, 0, 1)
        else
            btn:GetFontString():SetTextColor(0.9, 0.9, 0.9, 1)
        end
        
        btn:SetScript("OnClick", function()
            onSelect(item.key)
            UI:CloseDropdownMenu()
            clickDetector:Hide()
        end)
        
        offsetY = offsetY + 20
    end
    
    DropdownMenu.Child:SetHeight(offsetY)
    
    local height = math.min(180, math.max(40, offsetY + 12))
    DropdownMenu:SetHeight(height)
    
    DropdownMenu:Show()
    clickDetector:Show()
end
