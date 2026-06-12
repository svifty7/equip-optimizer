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

-- Skin standard AceGUI main frame with ElvUI styles
function ElvUI_Skin:SkinFrame(widget)
    if not self.S then return end
    
    local frame = widget.frame
    if frame then
        -- Apply ElvUI window frame skin
        self.S:HandleFrame(frame)
        
        -- Clean up default AceGUI frame decor
        if widget.titlebg then widget.titlebg:Hide() end
        if widget.titlebg_l then widget.titlebg_l:Hide() end
        if widget.titlebg_r then widget.titlebg_r:Hide() end
        
        -- Custom ElvUI title adjustments
        if widget.titletext then
            widget.titletext:SetTextColor(1, 0.8, 0, 1)
        end
    end
end

-- Wait for ADDON_LOADED to initialize
local skinFrame = CreateFrame("Frame")
skinFrame:RegisterEvent("ADDON_LOADED")
skinFrame:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        ElvUI_Skin:Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
