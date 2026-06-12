-- Basic.lua for EquipOptimizer
local addonName, addonTable = ...
local UI = addonTable.UI or {}
addonTable.UI = UI

function UI:CreateBackdropFrame(parent, titleText)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    f:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
    
    if titleText then
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 12, 8)
        t:SetText(titleText)
        f.Title = t
    end
    
    return f
end

function UI:CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width - 38, height)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width - 38, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    return scrollFrame, scrollChild
end

function UI:CreateEditBox(parent, width, height, labelText)
    local ebFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ebFrame:SetSize(width, height)
    ebFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    ebFrame:SetBackdropColor(0, 0, 0, 0.6)
    ebFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local eb = CreateFrame("EditBox", nil, ebFrame)
    eb:SetSize(width - 12, height - 4)
    eb:SetPoint("CENTER", ebFrame, "CENTER", 0, 0)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    
    if labelText and labelText ~= "" then
        local label = ebFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOMLEFT", ebFrame, "TOPLEFT", 0, 2)
        label:SetText(labelText)
        ebFrame.label = label
    end
    
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    eb:SetScript("OnEditFocusGained", function(self)
        ebFrame:SetBackdropBorderColor(0.8, 0.7, 0.2, 1)
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        ebFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end)
    
    return ebFrame, eb
end

function UI:CreateDropdown(parent, width, labelText)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    btn:SetBackdropColor(0, 0, 0, 0.6)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btn.text = text
    
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    
    if labelText and labelText ~= "" then
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
        label:SetText(labelText)
        btn.label = label
    end
    
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.7, 0.2, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end)
    
    return btn
end

function UI:CreateStyledButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    btn:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text)
    btn.text = label
    
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.7, 0.2, 1)
        self.text:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        if self.isSelected then
            self:SetBackdropBorderColor(0.8, 0.6, 0, 1)
            self.text:SetTextColor(1, 1, 1)
        else
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            self.text:SetTextColor(1, 0.82, 0)
        end
    end)
    
    return btn
end

function UI:SetButtonDisabled(btn, disabled)
    if disabled then
        btn:Disable()
        btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        btn.text:SetTextColor(0.4, 0.4, 0.4, 1)
    else
        btn:Enable()
        btn:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        btn.text:SetTextColor(1, 0.82, 0, 1)
    end
end

function UI:ClearContainer(container)
    local children = { container:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
end
