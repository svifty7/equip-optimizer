-- UI.lua for EquipOptimizer
local addonName, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local ItemEvaluator = addonTable.ItemEvaluator
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded


local UI = {}
addonTable.UI = UI
Core.UI = UI

local mainWindow = nil

-- Close dropdown on clicking anywhere else
local DropdownMenu = nil
local dropdownButtons = {}

local function CloseDropdownMenu()
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
    CloseDropdownMenu()
    clickDetector:Hide()
end)

local function OpenDropdownMenu(anchor, options, selectedValue, onSelect)
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
        table.insert(sorted, { key = k, val = v })
    end
    
    table.sort(sorted, function(a, b)
        if a.key == "equipped" then return true end
        if b.key == "equipped" then return false end
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
        
        if item.key and tostring(item.key):find("|Hitem:") then
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(item.key)
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
            CloseDropdownMenu()
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

-- UI helpers
local function CreateBackdropFrame(parent, titleText)
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

local function CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width - 25, height)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width - 25, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    return scrollFrame, scrollChild
end

local function CreateEditBox(parent, width, height, labelText)
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

local function CreateDropdown(parent, width, labelText)
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

local function CreateStyledButton(parent, width, height, text)
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

local function SetButtonDisabled(btn, disabled)
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

local function ClearContainer(container)
    local children = { container:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
end

function UI:IsWindowOpen()
    return mainWindow ~= nil and mainWindow:IsShown()
end

function UI:Toggle()
    if mainWindow and mainWindow:IsShown() then
        mainWindow:Hide()
    else
        self:Open()
    end
end

function UI:Refresh()
    if mainWindow and mainWindow:IsShown() then
        if mainWindow.selectedTab == "recs" then
            self:DrawRecs()
        else
            self:DrawSettings()
        end
    end
end

function UI:Open()
    if not mainWindow then
        self:CreateMainWindow()
    end
    mainWindow:Show()
    self:Refresh()
end

function UI:CreateMainWindow()
    if mainWindow then return end
    
    mainWindow = CreateFrame("Frame", "EquipOptimizerMainFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "EquipOptimizerMainFrame")
    mainWindow:SetSize(850, 600)
    -- Load saved window position or default to center
    local wDb = Core.db.profile.window
    if wDb and wDb.point then
        mainWindow:SetPoint(wDb.point, wDb.relativeTo or UIParent, wDb.relativePoint, wDb.xOfs, wDb.yOfs)
    else
        mainWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    mainWindow:SetMovable(true)
    mainWindow:EnableMouse(true)
    mainWindow:SetFrameStrata("HIGH")
    mainWindow:RegisterForDrag("LeftButton")
    mainWindow:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    mainWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        local relativeToName = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent"
        
        local wDb = Core.db.profile.window
        wDb.point = point
        wDb.relativeTo = relativeToName
        wDb.relativePoint = relativePoint
        wDb.xOfs = xOfs
        wDb.yOfs = yOfs
    end)
    
    mainWindow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    mainWindow:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    mainWindow:SetBackdropBorderColor(0.5, 0.4, 0.1, 1)
    
    local titleText = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", mainWindow, "TOP", 0, -15)
    titleText:SetText(L.ADDON_TITLE or "EquipOptimizer")
    
    local closeBtn = CreateFrame("Button", nil, mainWindow, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainWindow, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        mainWindow:Hide()
    end)
    
    local tabRecs = CreateStyledButton(mainWindow, 140, 26, L.RECOMMENDATIONS or "Recommendations")
    tabRecs:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 15, -45)
    
    local tabSettings = CreateStyledButton(mainWindow, 140, 26, L.SETTINGS or "Settings")
    tabSettings:SetPoint("LEFT", tabRecs, "RIGHT", 5, 0)
    
    local recsContainer = CreateFrame("Frame", nil, mainWindow)
    recsContainer:SetSize(810, 510)
    recsContainer:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 20, -80)
    mainWindow.recsContainer = recsContainer
    
    local settingsContainer = CreateFrame("Frame", nil, mainWindow)
    settingsContainer:SetSize(810, 510)
    settingsContainer:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 20, -80)
    mainWindow.settingsContainer = settingsContainer
    
    local function SelectTab(tabName)
        mainWindow.selectedTab = tabName
        if tabName == "recs" then
            tabRecs.isSelected = true
            tabRecs:SetBackdropBorderColor(0.8, 0.6, 0, 1)
            tabRecs.text:SetTextColor(1, 1, 1)
            
            tabSettings.isSelected = false
            tabSettings:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            tabSettings.text:SetTextColor(1, 0.82, 0)
            
            recsContainer:Show()
            settingsContainer:Hide()
            UI:DrawRecs()
        else
            tabRecs.isSelected = false
            tabRecs:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            tabRecs.text:SetTextColor(1, 0.82, 0)
            
            tabSettings.isSelected = true
            tabSettings:SetBackdropBorderColor(0.8, 0.6, 0, 1)
            tabSettings.text:SetTextColor(1, 1, 1)
            
            recsContainer:Hide()
            settingsContainer:Show()
            UI:DrawSettings()
        end
    end
    
    tabRecs:SetScript("OnClick", function() SelectTab("recs") end)
    tabSettings:SetScript("OnClick", function() SelectTab("settings") end)
    
    SelectTab("recs")
    
    if Core.ElvUI_Skin and IsAddOnLoaded("ElvUI") then
        local E = unpack(_G.ElvUI)
        local S = E:GetModule('Skins')
        if S then
            S:HandleFrame(mainWindow)
            S:HandleCloseButton(closeBtn)
        end
    end
end

function UI:DrawSettings()
    local settingsContainer = mainWindow.settingsContainer
    ClearContainer(settingsContainer)
    
    -- 1. Profile Panel
    local profilePanel = CreateBackdropFrame(settingsContainer, L.PROFILE_MANAGEMENT or "Profile Management")
    profilePanel:SetSize(810, 120)
    profilePanel:SetPoint("TOPLEFT", settingsContainer, "TOPLEFT", 0, -10)
    
    -- Active profile dropdown
    local activeBtn = CreateDropdown(profilePanel, 160, L.ACTIVE_PROFILE or "Active Profile")
    activeBtn:SetPoint("TOPLEFT", profilePanel, "TOPLEFT", 15, -35)
    
    local activeName = nil
    if Core.db.char.profiles then
        for name, data in pairs(Core.db.char.profiles) do
            if data == Core.activeProfile then
                activeName = name
                break
            end
        end
    end
    activeBtn.text:SetText(activeName or "")
    
    activeBtn:SetScript("OnClick", function()
        local list = {}
        if Core.db.char.profiles then
            for name in pairs(Core.db.char.profiles) do
                list[name] = name
            end
        end
        OpenDropdownMenu(activeBtn, list, activeName, function(key)
            local specKey = Core:GetSpecConfigKey()
            Core.db.char.activeProfileBySpec[specKey] = key
            Core.activeProfile = Core.db.char.profiles[key]
            Core:ValidateAndMigrateProfile()
            UI:Refresh()
        end)
    end)
    
    -- Rename input
    local renameFrame, renameEB = CreateEditBox(profilePanel, 140, 22, L.RENAME_PROFILE or "Rename Profile")
    renameFrame:SetPoint("LEFT", activeBtn, "RIGHT", 10, 0)
    renameEB:SetText(activeName or "")
    renameEB:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            if text == activeName then return end
            if Core.db.char.profiles[text] then
                Core:Print("|cffff0000Профиль с таким именем уже существует!|r")
                return
            end
            Core.db.char.profiles[text] = Core.db.char.profiles[activeName]
            Core.db.char.profiles[activeName] = nil
            
            for k, name in pairs(Core.db.char.activeProfileBySpec) do
                if name == activeName then
                    Core.db.char.activeProfileBySpec[k] = text
                end
            end
            
            Core.activeProfile = Core.db.char.profiles[text]
            UI:Refresh()
        end
    end)
    
    -- New profile input
    local newFrame, newEB = CreateEditBox(profilePanel, 140, 22, L.NEW_PROFILE_NAME or "New Profile")
    newFrame:SetPoint("LEFT", renameFrame, "RIGHT", 10, 0)
    newEB:SetText("")
    newEB:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            if Core.db.char.profiles[text] then
                Core:Print("|cffff0000Профиль с таким именем уже существует!|r")
                return
            end
            Core.db.char.profiles[text] = {
                rules = {
                    { stat = "STAT_ILVL", enabled = true, op = "MAX", value = 0 },
                    { stat = "STAT_HASTE", enabled = true, op = "MAX", value = 0 },
                    { stat = "STAT_VERSATILITY", enabled = true, op = "MAX", value = 0 },
                    { stat = "STAT_CRIT", enabled = true, op = "MAX", value = 0 },
                    { stat = "STAT_MASTERY", enabled = true, op = "MAX", value = 0 },
                },
                lockedSlots = {}
            }
            local specKey = Core:GetSpecConfigKey()
            Core.db.char.activeProfileBySpec[specKey] = text
            Core.activeProfile = Core.db.char.profiles[text]
            Core:ValidateAndMigrateProfile()
            UI:Refresh()
        end
    end)
    
    -- Delete Button
    local btnDelete = CreateStyledButton(profilePanel, 75, 22, L.DELETE or "Delete")
    btnDelete:SetPoint("LEFT", newFrame, "RIGHT", 10, 0)
    
    local profileCount = 0
    if Core.db.char.profiles then
        for _ in pairs(Core.db.char.profiles) do
            profileCount = profileCount + 1
        end
    end
    SetButtonDisabled(btnDelete, profileCount <= 1 or not activeName)
    
    btnDelete:SetScript("OnClick", function()
        if activeName then
            local nextName = nil
            for name in pairs(Core.db.char.profiles) do
                if name ~= activeName then
                    nextName = name
                    break
                end
            end
            if nextName then
                local specKey = Core:GetSpecConfigKey()
                Core.db.char.activeProfileBySpec[specKey] = nextName
                Core.db.char.profiles[activeName] = nil
                Core.activeProfile = Core.db.char.profiles[nextName]
                Core:ValidateAndMigrateProfile()
                UI:Refresh()
            end
        end
    end)
    
    -- Export/Import buttons
    local btnExport = CreateStyledButton(profilePanel, 75, 22, L.EXPORT or "Export")
    btnExport:SetPoint("LEFT", btnDelete, "RIGHT", 5, 0)
    
    local btnImport = CreateStyledButton(profilePanel, 75, 22, L.IMPORT or "Import")
    btnImport:SetPoint("LEFT", btnExport, "RIGHT", 5, 0)
    
    -- Import/Export string box
    local ioFrame, ioEB = CreateEditBox(profilePanel, 770, 22, L.IMPORT_EXPORT_STRING or "Import/Export String")
    ioFrame:SetPoint("TOPLEFT", activeBtn, "BOTTOMLEFT", 0, -25)
    ioEB:SetText("")
    ioEB:SetEnabled(false)
    
    btnExport:SetScript("OnClick", function()
        local str = Core:ExportProfileToString()
        ioEB:SetEnabled(true)
        ioEB:SetText(str)
        ioEB:HighlightText()
        ioEB:SetFocus()
    end)
    
    btnImport:SetScript("OnClick", function()
        ioEB:SetEnabled(true)
        ioEB:SetText("")
        ioEB:SetFocus()
    end)
    
    ioEB:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            local ok, err = Core:ImportProfileFromString(text)
            if ok then
                Core:Print("|cff00ff00Профиль успешно импортирован!|r")
                UI:Refresh()
            else
                Core:Print("|cffff0000Ошибка импорта: " .. tostring(err) .. "|r")
            end
        end
    end)
    
    -- 2. Left Column: Reserved Slots
    local leftColumn = CreateBackdropFrame(settingsContainer, L.SLOT_LOCKS or "Reserved Slots")
    leftColumn:SetSize(395, 350)
    leftColumn:SetPoint("TOPLEFT", profilePanel, "BOTTOMLEFT", 0, -15)
    
    local leftScroll, leftChild = CreateScrollFrame(leftColumn, 395, 310)
    leftScroll:SetPoint("TOPLEFT", leftColumn, "TOPLEFT", 10, -30)
    
    local offsetY = 0
    for _, slotInfo in ipairs(Core.Slots) do
        local slotId = slotInfo.id
        
        local row = CreateFrame("Frame", nil, leftChild)
        row:SetSize(360, 26)
        row:SetPoint("TOPLEFT", leftChild, "TOPLEFT", 0, -offsetY)
        
        local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("LEFT", row, "LEFT", 0, 0)
        cb.Text:SetText(L[slotInfo.label] or slotInfo.name)
        cb.Text:SetFontObject(GameFontHighlight)
        cb:SetChecked(Core.activeProfile.lockedSlots[slotId] ~= nil)
        
        local ddBtn = CreateDropdown(row, 200, "")
        ddBtn:SetPoint("LEFT", row, "LEFT", 150, 0)
        
        local function UpdateDropdownState()
            local lockVal = Core.activeProfile.lockedSlots[slotId]
            if lockVal == nil then
                ddBtn:Disable()
                ddBtn:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
                ddBtn.text:SetTextColor(0.4, 0.4, 0.4, 1)
                ddBtn.text:SetText(L.CURRENTLY_EQUIPPED)
            else
                ddBtn:Enable()
                ddBtn:SetBackdropColor(0, 0, 0, 0.6)
                ddBtn.text:SetTextColor(1, 0.82, 0, 1)
                if lockVal == true or lockVal == "equipped" then
                    ddBtn.text:SetText(L.CURRENTLY_EQUIPPED)
                else
                    ddBtn.text:SetText(lockVal)
                end
            end
        end
        UpdateDropdownState()
        
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            if checked then
                Core.activeProfile.lockedSlots[slotId] = "equipped"
            else
                Core.activeProfile.lockedSlots[slotId] = nil
            end
            UpdateDropdownState()
            ItemEvaluator:Optimize()
            if UI:IsWindowOpen() and mainWindow.selectedTab == "recs" then
                UI:Refresh()
            end
        end)
        
        ddBtn:SetScript("OnClick", function()
            local list = {}
            list["equipped"] = L.CURRENTLY_EQUIPPED
            
            local equippedItems = ItemEvaluator:GetEquippedItemsForSlot(slotId)
            for _, item in ipairs(equippedItems) do
                list[item.link] = item.link
            end
            
            local bagItems = ItemEvaluator:GetBagItemsForSlot(slotId)
            for _, item in ipairs(bagItems) do
                list[item.link] = item.link
            end
            
            local lockVal = Core.activeProfile.lockedSlots[slotId] or "equipped"
            OpenDropdownMenu(ddBtn, list, lockVal, function(key)
                Core.activeProfile.lockedSlots[slotId] = key
                UpdateDropdownState()
                ItemEvaluator:Optimize()
                if UI:IsWindowOpen() and mainWindow.selectedTab == "recs" then
                    UI:Refresh()
                end
            end)
        end)
        
        offsetY = offsetY + 28
    end
    leftChild:SetHeight(offsetY)
    
    -- 3. Right Column: Stat Rules
    local rightColumn = CreateBackdropFrame(settingsContainer, L.RULES or "Stat Rules")
    rightColumn:SetSize(400, 350)
    rightColumn:SetPoint("TOPLEFT", profilePanel, "BOTTOMLEFT", 410, -15)
    
    local helpBtn = CreateFrame("Button", nil, rightColumn)
    helpBtn:SetSize(20, 20)
    helpBtn:SetPoint("TOPRIGHT", rightColumn, "TOPRIGHT", -12, 8)
    
    local helpText = helpBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpText:SetPoint("CENTER", helpBtn, "CENTER", 0, 0)
    helpText:SetText("[?]")
    helpText:SetTextColor(0.8, 0.8, 0.8, 1)
    
    helpBtn:SetScript("OnEnter", function(self)
        helpText:SetTextColor(1, 0.82, 0, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L.HELP_TOOLTIP_TITLE or "Как настраивать характеристики:", 1, 0.82, 0)
        GameTooltip:AddLine(L.HELP_TOOLTIP_MIN or "", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(L.HELP_TOOLTIP_MAX or "", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(L.HELP_TOOLTIP_ORDER or "", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function()
        helpText:SetTextColor(0.8, 0.8, 0.8, 1)
        GameTooltip:Hide()
    end)
    
    local rightScroll, rightChild = CreateScrollFrame(rightColumn, 400, 310)
    rightScroll:SetPoint("TOPLEFT", rightColumn, "TOPLEFT", 10, -30)
    
    local function RefreshRulesList()
        local children = { rightChild:GetChildren() }
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        
        local rules = Core.activeProfile.rules or {}
        local yOffset = 0
        
        local function IsTertiaryStat(statKey)
            return statKey == "STAT_LEECH" or statKey == "STAT_AVOIDANCE" or statKey == "STAT_SPEED"
        end
        
        local renderedSecondaryHeader = false
        local renderedTertiaryHeader = false
        
        for idx, rule in ipairs(rules) do
            if rule.stat ~= "STAT_ILVL" then
                local isTert = IsTertiaryStat(rule.stat)
                
                -- Render section header if needed
                if not isTert and not renderedSecondaryHeader then
                    renderedSecondaryHeader = true
                    
                    local headerRow = CreateFrame("Frame", nil, rightChild)
                    headerRow:SetSize(370, 18)
                    headerRow:SetPoint("TOPLEFT", rightChild, "TOPLEFT", 0, -yOffset)
                    
                    local headerText = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    headerText:SetPoint("LEFT", headerRow, "LEFT", 5, 0)
                    headerText:SetText(L.STAT_GROUP_SECONDARY or "Secondary Stats")
                    headerText:SetTextColor(1, 0.82, 0, 1) -- Golden color
                    
                    local line = headerRow:CreateTexture(nil, "ARTWORK")
                    line:SetSize(360, 1)
                    line:SetColorTexture(0.3, 0.3, 0.3, 0.4)
                    line:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 5, -2)
                    
                    yOffset = yOffset + 24
                elseif isTert and not renderedTertiaryHeader then
                    renderedTertiaryHeader = true
                    
                    local headerRow = CreateFrame("Frame", nil, rightChild)
                    headerRow:SetSize(370, 18)
                    headerRow:SetPoint("TOPLEFT", rightChild, "TOPLEFT", 0, -yOffset)
                    
                    local headerText = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    headerText:SetPoint("LEFT", headerRow, "LEFT", 5, 0)
                    headerText:SetText(L.STAT_GROUP_TERTIARY or "Tertiary Stats")
                    headerText:SetTextColor(1, 0.82, 0, 1) -- Golden color
                    
                    local line = headerRow:CreateTexture(nil, "ARTWORK")
                    line:SetSize(360, 1)
                    line:SetColorTexture(0.3, 0.3, 0.3, 0.4)
                    line:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 5, -2)
                    
                    yOffset = yOffset + 24
                end
                
                local row = CreateFrame("Frame", nil, rightChild)
                row:SetSize(370, 28)
                row:SetPoint("TOPLEFT", rightChild, "TOPLEFT", 0, -yOffset)
                
                local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
                cb:SetPoint("LEFT", row, "LEFT", 0, 0)
                cb:SetChecked(rule.enabled)
                
                local baseText = L[rule.stat] or rule.stat
                local currentVal = 0
                local currentPct = 0
                local isPercent = false
                
                local eqStats = ItemEvaluator:GetEquippedStats()
                if rule.stat == "STAT_HASTE" then
                    currentVal = eqStats.STAT_HASTE or 0
                    local rating_per_percent = ItemEvaluator:GetRatingPerPercent(18)
                    currentPct = rating_per_percent > 0 and (currentVal / rating_per_percent) or 0
                    isPercent = true
                elseif rule.stat == "STAT_CRIT" then
                    currentVal = eqStats.STAT_CRIT or 0
                    local rating_per_percent = ItemEvaluator:GetRatingPerPercent(9)
                    currentPct = rating_per_percent > 0 and (currentVal / rating_per_percent) or 0
                    isPercent = true
                elseif rule.stat == "STAT_MASTERY" then
                    currentVal = eqStats.STAT_MASTERY or 0
                    local rating_per_percent = ItemEvaluator:GetRatingPerPercent(26)
                    currentPct = rating_per_percent > 0 and (currentVal / rating_per_percent) or 0
                    isPercent = true
                elseif rule.stat == "STAT_VERSATILITY" then
                    currentVal = eqStats.STAT_VERSATILITY or 0
                    local rating_per_percent = ItemEvaluator:GetRatingPerPercent(29)
                    currentPct = rating_per_percent > 0 and (currentVal / rating_per_percent) or 0
                    isPercent = true
                elseif rule.stat == "STAT_LEECH" then
                    currentVal = eqStats.STAT_LEECH or 0
                    currentPct = currentVal / 1100
                    isPercent = true
                elseif rule.stat == "STAT_AVOIDANCE" then
                    currentVal = eqStats.STAT_AVOIDANCE or 0
                    currentPct = currentVal / 1100
                    isPercent = true
                elseif rule.stat == "STAT_SPEED" then
                    currentVal = eqStats.STAT_SPEED or 0
                    currentPct = currentVal / 1100
                    isPercent = true
                end
                
                local displayText = baseText
                if isPercent then
                    local cleanText = baseText:gsub(" ?%(%%%)", "")
                    displayText = string.format("%s (%.2f%% / %d)", cleanText, currentPct, currentVal)
                end
                
                local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                lbl:SetPoint("LEFT", row, "LEFT", 30, 0)
                lbl:SetText(displayText)
                lbl:SetWidth(165)
                lbl:SetJustifyH("LEFT")
                
                local ddOp = CreateDropdown(row, 65, "")
                ddOp:SetPoint("LEFT", row, "LEFT", 200, 0)
                
                local displayOp = rule.op or "MAX"
                ddOp.text:SetText(displayOp)
                
                local valFrame, valEB = CreateEditBox(row, 45, 20, "")
                valFrame:SetPoint("LEFT", ddOp, "RIGHT", 5, 0)
                valEB:SetText(tostring(rule.value or 0))
                
                local function UpdateValueState()
                    local op = rule.op or "MAX"
                    if op == "MAX" then
                        valEB:SetEnabled(false)
                        valEB:SetTextColor(0.4, 0.4, 0.4, 1)
                        valEB:SetText("0")
                    else
                        valEB:SetEnabled(true)
                        valEB:SetTextColor(1, 1, 1, 1)
                        valEB:SetText(tostring(rule.value or 0))
                    end
                end
                UpdateValueState()
                
                local function UpdateRowState()
                    if not cb:GetChecked() then
                        ddOp:Disable()
                        ddOp:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
                        ddOp.text:SetTextColor(0.4, 0.4, 0.4, 1)
                        valEB:SetEnabled(false)
                        valEB:SetTextColor(0.4, 0.4, 0.4, 1)
                    else
                        ddOp:Enable()
                        ddOp:SetBackdropColor(0, 0, 0, 0.6)
                        ddOp.text:SetTextColor(1, 0.82, 0, 1)
                        UpdateValueState()
                    end
                end
                UpdateRowState()
                
                local btnUp = CreateFrame("Button", nil, row)
                btnUp:SetSize(22, 22)
                btnUp:SetPoint("LEFT", valFrame, "RIGHT", 5, 0)
                btnUp:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
                btnUp:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
                btnUp:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
                btnUp:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                
                local isTert = IsTertiaryStat(rule.stat)
                
                local disableUp = (idx <= 2) or (IsTertiaryStat(rules[idx-1].stat) ~= isTert)
                if disableUp then
                    btnUp:Disable()
                end
                
                local btnDown = CreateFrame("Button", nil, row)
                btnDown:SetSize(22, 22)
                btnDown:SetPoint("LEFT", btnUp, "RIGHT", 2, 0)
                btnDown:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
                btnDown:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
                btnDown:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
                btnDown:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                
                local disableDown = (idx == #rules) or (IsTertiaryStat(rules[idx+1].stat) ~= isTert)
                if disableDown then
                    btnDown:Disable()
                end
                
                cb:SetScript("OnClick", function(self)
                    rule.enabled = self:GetChecked()
                    UpdateRowState()
                    ItemEvaluator:Optimize()
                    if UI:IsWindowOpen() and mainWindow.selectedTab == "recs" then
                        UI:Refresh()
                    end
                end)
                
                ddOp:SetScript("OnClick", function()
                    local opList = {
                        [">="] = "Минимум (%)",
                        ["MAX"] = "Максимизировать"
                    }
                    OpenDropdownMenu(ddOp, opList, rule.op or "MAX", function(key)
                        rule.op = key
                        ddOp.text:SetText(key)
                        UpdateValueState()
                        ItemEvaluator:Optimize()
                        if UI:IsWindowOpen() and mainWindow.selectedTab == "recs" then
                            UI:Refresh()
                        end
                    end)
                end)
                
                valEB:SetScript("OnEnterPressed", function(self)
                    rule.value = tonumber(self:GetText()) or 0
                    self:ClearFocus()
                    ItemEvaluator:Optimize()
                    if UI:IsWindowOpen() and mainWindow.selectedTab == "recs" then
                        UI:Refresh()
                    end
                end)
                valEB:SetScript("OnEditFocusLost", function(self)
                    rule.value = tonumber(self:GetText()) or 0
                    ItemEvaluator:Optimize()
                    if UI:IsWindowOpen() and mainWindow.selectedTab == "recs" then
                        UI:Refresh()
                    end
                end)
                
                btnUp:SetScript("OnClick", function()
                    local tmp = rules[idx]
                    rules[idx] = rules[idx-1]
                    rules[idx-1] = tmp
                    RefreshRulesList()
                    ItemEvaluator:Optimize()
                end)
                
                btnDown:SetScript("OnClick", function()
                    local tmp = rules[idx]
                    rules[idx] = rules[idx+1]
                    rules[idx+1] = tmp
                    RefreshRulesList()
                    ItemEvaluator:Optimize()
                end)
                
                yOffset = yOffset + 30
            end
        end
        rightChild:SetHeight(yOffset)
    end
    
    RefreshRulesList()
end

function UI:DrawRecs()
    local recsContainer = mainWindow.recsContainer
    ClearContainer(recsContainer)
    
    local recs, predictedStats = ItemEvaluator:Optimize()
    
    local title = recsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 10, -10)
    title:SetText(L.RECOMMENDATIONS or "Recommendations")
    
    local recsScroll, recsChild = CreateScrollFrame(recsContainer, 810, 250)
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
            
            local function CreateTooltipArea(strString, itemLink)
                if not itemLink then return end
                local frameTip = CreateFrame("Button", nil, row)
                frameTip:SetAllPoints(strString)
                frameTip:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(itemLink)
                    GameTooltip:Show()
                end)
                frameTip:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end
            CreateTooltipArea(lblCurrent, rec.currentLink)
            CreateTooltipArea(lblRec, rec.recommendedLink)
            
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
    local primaryPanel = CreateBackdropFrame(recsContainer, L.PRIMARY_STATS or "Primary Stats")
    primaryPanel:SetSize(390, 115)
    primaryPanel:SetPoint("TOPLEFT", recsContainer, "TOPLEFT", 0, -305)
    
    local secondaryPanel = CreateBackdropFrame(recsContainer, L.SECONDARY_STATS or "Secondary Stats")
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
        { key = "STAT_HASTE", label = L.STAT_HASTE, isPercent = true, ratingIndex = 18 },
        { key = "STAT_CRIT", label = L.STAT_CRIT, isPercent = true, ratingIndex = 9 },
        { key = "STAT_MASTERY", label = L.STAT_MASTERY, isPercent = true, ratingIndex = 26 },
        { key = "STAT_VERSATILITY", label = L.STAT_VERSATILITY, isPercent = true, ratingIndex = 29 },
    }
    
    local function RenderPanelStats(panel, statsList, startY, rowHeight)
        local offsetY = startY
        local eqStats = ItemEvaluator:GetEquippedStats()
        for _, statInfo in ipairs(statsList) do
            local key = statInfo.key
            local currentVal = 0
            local currentPct = 0
            
            if key == "STAT_ILVL" then
                local _, avgIlvl = GetAverageItemLevel()
                currentVal = avgIlvl or 0
            elseif key == "STAT_ARMOR" then
                currentVal = select(2, UnitArmor("player")) or 0
            elseif key == "STAT_STRENGTH" then
                currentVal = select(2, UnitStat("player", 1)) or 0
            elseif key == "STAT_AGILITY" then
                currentVal = select(2, UnitStat("player", 2)) or 0
            elseif key == "STAT_INTELLECT" then
                currentVal = select(2, UnitStat("player", 4)) or 0
            elseif key == "STAT_STAMINA" then
                currentVal = select(2, UnitStat("player", 3)) or 0
            elseif key == "STAT_HASTE" then
                currentVal = eqStats.STAT_HASTE or 0
                local rating_per_percent = ItemEvaluator:GetRatingPerPercent(18)
                currentPct = rating_per_percent > 0 and (currentVal / rating_per_percent) or 0
            elseif key == "STAT_CRIT" then
                currentVal = eqStats.STAT_CRIT or 0
                local rating_per_percent = ItemEvaluator:GetRatingPerPercent(9)
                currentPct = rating_per_percent > 0 and (currentVal / rating_per_percent) or 0
            elseif key == "STAT_MASTERY" then
                currentVal = eqStats.STAT_MASTERY or 0
                local rating_per_percent = ItemEvaluator:GetRatingPerPercent(26)
                currentPct = rating_per_percent > 0 and (currentVal / rating_per_percent) or 0
            elseif key == "STAT_VERSATILITY" then
                currentVal = eqStats.STAT_VERSATILITY or 0
                local rating_per_percent = ItemEvaluator:GetRatingPerPercent(29)
                currentPct = rating_per_percent > 0 and (currentVal / rating_per_percent) or 0
            end
            
            local predictedVal = predictedStats[key] or currentVal
            local diffRating = predictedVal - currentVal
            
            local valStr, diffStr = "", ""
            local cleanLabel = statInfo.label
            
            if statInfo.isPercent then
                cleanLabel = statInfo.label:gsub(" ?%(%%%)", "")
                -- Calculate predicted percentage
                local rating_per_percent = ItemEvaluator:GetRatingPerPercent(statInfo.ratingIndex)
                local predictedPct = currentPct + (rating_per_percent > 0 and ((predictedVal - currentVal) / rating_per_percent) or 0)
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
    local equipBtn = CreateStyledButton(recsContainer, 790, 35, L.EQUIP_BEST or "Equip Best")
    equipBtn:SetPoint("TOPLEFT", primaryPanel, "BOTTOMLEFT", 0, -15)
    
    local function UpdateButtonState()
        if InCombatLockdown() then
            SetButtonDisabled(equipBtn, true)
            equipBtn.text:SetText(L.IN_COMBAT or "In Combat")
        else
            local hasRecs = false
            for _ in pairs(recs) do
                hasRecs = true
                break
            end
            SetButtonDisabled(equipBtn, not hasRecs)
            equipBtn.text:SetText(L.EQUIP_BEST or "Equip Best")
        end
    end
    
    UpdateButtonState()
    equipBtn:SetScript("OnClick", function()
        ItemEvaluator:EquipRecommended(recs)
    end)
end

-- Event monitoring frame for auto-refresh and combat check
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if unit ~= "player" then return end
    end
    if UI:IsWindowOpen() then
        UI:Refresh()
    end
end)
