-- Core.lua for EquipOptimizer
local _, addonTable = ...

-- Initialize Addon
local EquipOptimizer = LibStub("AceAddon-3.0"):NewAddon("EquipOptimizer", "AceEvent-3.0", "AceConsole-3.0")
addonTable.Core = EquipOptimizer
_G.EquipOptimizer = EquipOptimizer -- Make it globally accessible for other files

-- Define standard inventory slots
EquipOptimizer.Slots = {
    { id = 1,  name = "HEAD",      label = "Slot_HEAD" },
    { id = 2,  name = "NECK",      label = "Slot_NECK" },
    { id = 3,  name = "SHOULDER",  label = "Slot_SHOULDER" },
    { id = 15, name = "BACK",      label = "Slot_BACK" },
    { id = 5,  name = "CHEST",     label = "Slot_CHEST" },
    { id = 9,  name = "WRIST",     label = "Slot_WRIST" },
    { id = 10, name = "HANDS",     label = "Slot_HANDS" },
    { id = 6,  name = "WAIST",     label = "Slot_WAIST" },
    { id = 7,  name = "LEGS",      label = "Slot_LEGS" },
    { id = 8,  name = "FEET",      label = "Slot_FEET" },
    { id = 11, name = "FINGER1",   label = "Slot_FINGER1" },
    { id = 12, name = "FINGER2",   label = "Slot_FINGER2" },
    { id = 13, name = "TRINKET1",  label = "Slot_TRINKET1" },
    { id = 14, name = "TRINKET2",  label = "Slot_TRINKET2" },
    { id = 16, name = "MAINHAND",  label = "Slot_MAINHAND" },
    { id = 17, name = "OFFHAND",   label = "Slot_OFFHAND" },
}

-- Default DB structure
local dbDefaults = {
    char = {
        activeProfileBySpec = {},
        profiles = {}
    },
    profile = {
        minimap = {
            minimapAngle = 45,
            hide = false
        },
        window = {
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER",
            xOfs = 0,
            yOfs = 0
        }
    }
}

function EquipOptimizer:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("EquipOptimizerDB", dbDefaults, true)
    
    -- Setup profile based on character + spec
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    
    -- Register slash commands
    self:RegisterChatCommand("eo", "ToggleWindow")
    self:RegisterChatCommand("equipopt", "ToggleWindow")
    
    self:Print("|cff00ff00EquipOptimizer loaded. Use /eo to open configuration.|r")
end

function EquipOptimizer:OnPlayerEnteringWorld(event)
    self:UpdateProfile()
    if self.CreateMinimapButton then
        self:CreateMinimapButton()
    end
    if addonTable.ItemEvaluator and addonTable.ItemEvaluator.RequestLoadGems then
        addonTable.ItemEvaluator:RequestLoadGems()
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function EquipOptimizer:OnSpecChanged(event, unit)
    if unit == "player" then
        self:UpdateProfile()
    end
end

function EquipOptimizer:ToggleWindow()
    if self.UI then
        self.UI:Toggle()
    else
        self:Print("UI module is not loaded.")
    end
end

-- ShowDebugWindow and debug slash commands removed
