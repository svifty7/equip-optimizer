-- ElvUI_Skin.lua for EquipOptimizer
local addonName, addonTable = ...
local Core = addonTable.Core
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local ElvUI_Skin = {}
Core.ElvUI_Skin = ElvUI_Skin

function ElvUI_Skin:Initialize()
    if not IsAddOnLoaded("ElvUI") then return end
    
    local E = _G.ElvUI and unpack(_G.ElvUI)
    if not E then return end
    
    local S = E:GetModule('Skins')
    if not S then return end
    
    self.E = E
    self.S = S
end


-- Wait for ADDON_LOADED to initialize
local skinFrame = CreateFrame("Frame")
skinFrame:RegisterEvent("ADDON_LOADED")
skinFrame:SetScript("OnEvent", function(self, _, name)
    if name == addonName then
        ElvUI_Skin:Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
