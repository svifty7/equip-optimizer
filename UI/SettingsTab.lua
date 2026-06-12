-- SettingsTab.lua for EquipOptimizer
local addonName, addonTable = ...
local UI = addonTable.UI

function UI:DrawSettings()
    local settingsContainer = self.mainWindow.settingsContainer
    self:ClearContainer(settingsContainer)
    
    -- Delegate panel drawing to sub-modules to keep files under 300 lines
    local profilePanel = self:DrawProfilePanel(settingsContainer)
    self:DrawReservedSlots(settingsContainer, profilePanel)
    self:DrawStatRules(settingsContainer, profilePanel)
end
