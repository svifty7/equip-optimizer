-- Minimap.lua for EquipOptimizer
local _, addonTable = ...
local Core = addonTable.Core
local L = addonTable.L
local ItemEvaluator = addonTable.ItemEvaluator

function Core:CreateMinimapButton()
    if self.MinimapButton then return end
    
    local MinimapButton = CreateFrame("Button", "EquipOptimizerMinimapButton", Minimap)
    MinimapButton:SetSize(31, 31)
    MinimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    MinimapButton:SetMovable(true)
    MinimapButton:SetToplevel(true)
    
    -- Background icon
    local background = MinimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    background:SetPoint("CENTER", 0, 0)
    MinimapButton.background = background
    
    -- Round border
    local border = MinimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", 0, 0)
    MinimapButton.border = border
    
    -- Highlight
    MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Position updater
    local function UpdatePosition(angle)
        local rad = math.rad(angle)
        local x = math.cos(rad) * 80
        local y = math.sin(rad) * 80
        MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    -- Dragging handlers
    MinimapButton:RegisterForDrag("LeftButton")
    MinimapButton:RegisterForClicks("LeftButtonUp")
    
    MinimapButton:SetScript("OnDragStart", function(selfBtn)
        selfBtn.isDragging = true
    end)
    
    MinimapButton:SetScript("OnDragStop", function(selfBtn)
        selfBtn.isDragging = false
    end)
    
    MinimapButton:SetScript("OnUpdate", function(selfBtn)
        if selfBtn.isDragging then
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx * scale, cy * scale
            local angle = math.atan2(y - cy, x - cx)
            local angleDeg = math.deg(angle)
            Core.db.profile.minimap.minimapAngle = angleDeg
            UpdatePosition(angleDeg)
        end
    end)
    
    MinimapButton:SetScript("OnClick", function(selfBtn, button)
        Core:ToggleWindow()
    end)
    
    MinimapButton:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_LEFT")
        GameTooltip:AddLine("EquipOptimizer")
        GameTooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT or "ЛКМ: Открыть настройки", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    MinimapButton:SetScript("OnLeave", function(selfBtn)
        GameTooltip:Hide()
    end)
    
    self.MinimapButton = MinimapButton
    
    -- Init position
    local angle = self.db.profile.minimap.minimapAngle or 45
    UpdatePosition(angle)
end
