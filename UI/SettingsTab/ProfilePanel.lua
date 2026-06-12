-- ProfilePanel.lua for EquipOptimizer
local addonName, addonTable = ...
local L = addonTable.L
local Core = addonTable.Core
local UI = addonTable.UI

function UI:DrawProfilePanel(settingsContainer)
    local profilePanel = self:CreateBackdropFrame(settingsContainer, L.PROFILE_MANAGEMENT or "Profile Management")
    profilePanel:SetSize(810, 120)
    profilePanel:SetPoint("TOPLEFT", settingsContainer, "TOPLEFT", 0, -10)
    
    -- Active profile dropdown
    local activeBtn = self:CreateDropdown(profilePanel, 160, L.ACTIVE_PROFILE or "Active Profile")
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
        self:OpenDropdownMenu(activeBtn, list, activeName, function(key)
            local specKey = Core:GetSpecConfigKey()
            Core.db.char.activeProfileBySpec[specKey] = key
            Core.activeProfile = Core.db.char.profiles[key]
            Core:ValidateAndMigrateProfile()
            self:Refresh()
        end)
    end)
    
    -- Rename input
    local renameFrame, renameEB = self:CreateEditBox(profilePanel, 140, 22, L.RENAME_PROFILE or "Rename Profile")
    renameFrame:SetPoint("LEFT", activeBtn, "RIGHT", 10, 0)
    renameEB:SetText(activeName or "")
    renameEB:SetScript("OnEnterPressed", function(eb)
        local text = eb:GetText()
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
            self:Refresh()
        end
    end)
    
    -- New profile input
    local newFrame, newEB = self:CreateEditBox(profilePanel, 140, 22, L.NEW_PROFILE_NAME or "New Profile")
    newFrame:SetPoint("LEFT", renameFrame, "RIGHT", 10, 0)
    newEB:SetText("")
    newEB:SetScript("OnEnterPressed", function(eb)
        local text = eb:GetText()
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
                lockedSlots = {},
                requiredSets = {}
            }
            local specKey = Core:GetSpecConfigKey()
            Core.db.char.activeProfileBySpec[specKey] = text
            Core.activeProfile = Core.db.char.profiles[text]
            Core:ValidateAndMigrateProfile()
            self:Refresh()
        end
    end)
    
    -- Delete Button
    local btnDelete = self:CreateStyledButton(profilePanel, 75, 22, L.DELETE or "Delete")
    btnDelete:SetPoint("LEFT", newFrame, "RIGHT", 10, 0)
    
    local profileCount = 0
    if Core.db.char.profiles then
        for _ in pairs(Core.db.char.profiles) do
            profileCount = profileCount + 1
        end
    end
    self:SetButtonDisabled(btnDelete, profileCount <= 1 or not activeName)
    
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
                self:Refresh()
            end
        end
    end)
    
    -- Export/Import buttons
    local btnExport = self:CreateStyledButton(profilePanel, 75, 22, L.EXPORT or "Export")
    btnExport:SetPoint("LEFT", btnDelete, "RIGHT", 5, 0)
    
    local btnImport = self:CreateStyledButton(profilePanel, 75, 22, L.IMPORT or "Import")
    btnImport:SetPoint("LEFT", btnExport, "RIGHT", 5, 0)
    
    -- Import/Export string box
    local ioFrame, ioEB = self:CreateEditBox(profilePanel, 770, 22, L.IMPORT_EXPORT_STRING or "Import/Export String")
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
    
    ioEB:SetScript("OnEnterPressed", function(eb)
        local text = eb:GetText()
        if text and text ~= "" then
            local ok, err = Core:ImportProfileFromString(text)
            if ok then
                Core:Print("|cff00ff00Профиль успешно импортирован!|r")
                self:Refresh()
            else
                Core:Print("|cffff0000Ошибка импорта: " .. tostring(err) .. "|r")
            end
        end
    end)
    
    return profilePanel
end
