-- SettingsTab.lua for EquipOptimizer
local addonName, addonTable = ...
local UI = addonTable.UI

function UI:DrawSettings()
    local settingsContainer = self.mainWindow.settingsContainer
    self:ClearContainer(settingsContainer)
    
    -- Delegate panel drawing to sub-modules to keep files under 300 lines
    local profilePanel = self:DrawProfilePanel(settingsContainer)
    local leftColumn = self:DrawReservedSlots(settingsContainer, profilePanel)
    local rightColumn = self:DrawStatRules(settingsContainer, profilePanel)
    self:DrawSetRequirements(settingsContainer, leftColumn, rightColumn)
end
