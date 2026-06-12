-- MainFrame.lua for EquipOptimizer
local addonName, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local UI = addonTable.UI

local mainWindow = nil
UI.mainWindow = nil

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
        elseif mainWindow.selectedTab == "gems" and self.DrawGems then
            self:DrawGems()
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
    UI.mainWindow = mainWindow
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
    
    local tabRecs = self:CreateStyledButton(mainWindow, 140, 26, L.RECOMMENDATIONS or "Recommendations")
    tabRecs:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 15, -45)
    
    local tabSettings = self:CreateStyledButton(mainWindow, 140, 26, L.SETTINGS or "Settings")
    tabSettings:SetPoint("LEFT", tabRecs, "RIGHT", 5, 0)
    
    -- Gems tab button
    local tabGems = self:CreateStyledButton(mainWindow, 140, 26, L.GEMS or "Gems")
    tabGems:SetPoint("LEFT", tabSettings, "RIGHT", 5, 0)
    UI.tabGemsBtn = tabGems
    
    local recsContainer = CreateFrame("Frame", nil, mainWindow)
    recsContainer:SetSize(810, 510)
    recsContainer:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 20, -80)
    mainWindow.recsContainer = recsContainer
    
    local settingsContainer = CreateFrame("Frame", nil, mainWindow)
    settingsContainer:SetSize(810, 510)
    settingsContainer:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 20, -80)
    mainWindow.settingsContainer = settingsContainer
    
    -- Gems container placeholder (added in stage 2)
    local gemsContainer = CreateFrame("Frame", nil, mainWindow)
    gemsContainer:SetSize(810, 510)
    gemsContainer:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 20, -80)
    gemsContainer:Hide()
    mainWindow.gemsContainer = gemsContainer
    
    local function SelectTab(tabName)
        mainWindow.selectedTab = tabName
        
        tabRecs.isSelected = (tabName == "recs")
        tabSettings.isSelected = (tabName == "settings")
        tabGems.isSelected = (tabName == "gems")
        
        local function UpdateTabStyle(btn)
            if btn.isSelected then
                btn:SetBackdropBorderColor(0.8, 0.6, 0, 1)
                btn.text:SetTextColor(1, 1, 1)
            else
                btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                btn.text:SetTextColor(1, 0.82, 0)
            end
        end
        
        UpdateTabStyle(tabRecs)
        UpdateTabStyle(tabSettings)
        UpdateTabStyle(tabGems)
        
        recsContainer:SetShown(tabName == "recs")
        settingsContainer:SetShown(tabName == "settings")
        gemsContainer:SetShown(tabName == "gems")
        
        if tabName == "recs" then
            UI:DrawRecs()
        elseif tabName == "gems" and UI.DrawGems then
            UI:DrawGems()
        else
            UI:DrawSettings()
        end
    end
    
    tabRecs:SetScript("OnClick", function() SelectTab("recs") end)
    tabSettings:SetScript("OnClick", function() SelectTab("settings") end)
    tabGems:SetScript("OnClick", function() SelectTab("gems") end)
    
    SelectTab("recs")
    
    local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if Core.ElvUI_Skin and IsAddOnLoaded("ElvUI") then
        local E = unpack(_G.ElvUI)
        local S = E:GetModule('Skins')
        if S then
            S:HandleFrame(mainWindow)
        end
    end
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
