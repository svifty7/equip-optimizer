-- Core.lua for EquipOptimizer
local addonName, addonTable = ...
local L = addonTable.L

-- Initialize Addon
EquipOptimizer = LibStub("AceAddon-3.0"):NewAddon("EquipOptimizer", "AceEvent-3.0", "AceConsole-3.0")
addonTable.Core = EquipOptimizer

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
        activeProfileBySpec = {
            -- [specIndex/configKey] = profileName
        },
        profiles = {
            -- [profileName] = { rules = {...}, lockedSlots = {...} }
        }
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

function EquipOptimizer:GetDefaultProfileName()
    local specIndex = GetSpecialization()
    local specName = "Unknown"
    if specIndex then
        local _, name = GetSpecializationInfo(specIndex)
        if name then
            specName = name
        end
    end
    
    local loadoutName = "Default"
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local configID = C_ClassTalents.GetActiveConfigID()
        if configID then
            local configInfo = C_Traits.GetConfigInfo(configID)
            if configInfo and configInfo.name and configInfo.name ~= "" then
                loadoutName = configInfo.name
            end
        end
    end
    
    return string.format("%s (%s)", specName, loadoutName)
end

function EquipOptimizer:ValidateAndMigrateProfile()
    local profile = self.activeProfile
    if not profile then return end
    if not profile.rules then
        profile.rules = {}
    end
    if not profile.lockedSlots then
        profile.lockedSlots = {}
    end
    
    local requiredStats = { "STAT_ILVL", "STAT_HASTE", "STAT_VERSATILITY", "STAT_CRIT", "STAT_MASTERY", "STAT_LEECH", "STAT_AVOIDANCE", "STAT_SPEED" }
    local hasStat = {}
    
    for _, r in ipairs(profile.rules) do
        hasStat[r.stat] = r
        if r.enabled == nil then
            r.enabled = true
        end
        if r.op == "max" or r.op == "MAX" then
            r.op = "MAX"
        elseif r.op == ">=" then
            r.op = ">="
        else
            if r.op == "min" or r.op == "MIN" then
                r.op = "MAX"
            else
                r.op = ">="
            end
        end
    end
    
    local newRules = {}
    
    local ilvlRule = hasStat["STAT_ILVL"]
    if not ilvlRule then
        ilvlRule = { stat = "STAT_ILVL", enabled = true, op = "MAX", value = 0 }
    else
        ilvlRule.enabled = true
        ilvlRule.op = "MAX"
        ilvlRule.value = 0
    end
    table.insert(newRules, ilvlRule)
    
    -- Add secondary stats in their current relative order
    for _, r in ipairs(profile.rules) do
        if r.stat ~= "STAT_ILVL" and r.stat ~= "STAT_LEECH" and r.stat ~= "STAT_AVOIDANCE" and r.stat ~= "STAT_SPEED" then
            table.insert(newRules, r)
        end
    end
    
    -- Add tertiary stats in their current relative order
    for _, r in ipairs(profile.rules) do
        if r.stat == "STAT_LEECH" or r.stat == "STAT_AVOIDANCE" or r.stat == "STAT_SPEED" then
            table.insert(newRules, r)
        end
    end
    
    -- Fill in missing required stats
    for _, reqStat in ipairs(requiredStats) do
        local found = false
        for _, r in ipairs(newRules) do
            if r.stat == reqStat then
                found = true
                break
            end
        end
        if not found then
            local isTertiary = (reqStat == "STAT_LEECH" or reqStat == "STAT_AVOIDANCE" or reqStat == "STAT_SPEED")
            if isTertiary then
                table.insert(newRules, { stat = reqStat, enabled = false, op = "MAX", value = 0 })
            else
                -- Insert secondary stat before the first tertiary stat to maintain grouping
                local insertIdx = #newRules + 1
                for i, r in ipairs(newRules) do
                    if r.stat == "STAT_LEECH" or r.stat == "STAT_AVOIDANCE" or r.stat == "STAT_SPEED" then
                        insertIdx = i
                        break
                    end
                end
                table.insert(newRules, insertIdx, { stat = reqStat, enabled = false, op = "MAX", value = 0 })
            end
        end
    end
    
    profile.rules = newRules
end

function EquipOptimizer:GetSpecConfigKey()
    local specIndex = GetSpecialization() or 1
    local configID = 0
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        configID = C_ClassTalents.GetActiveConfigID() or 0
    end
    return string.format("%d_%d", specIndex, configID)
end

function EquipOptimizer:UpdateProfile()
    if not self.db then return end
    
    local key = self:GetSpecConfigKey()
    if not self.db.char.activeProfileBySpec then
        self.db.char.activeProfileBySpec = {}
    end
    if not self.db.char.profiles then
        self.db.char.profiles = {}
    end
    
    local profileName = self.db.char.activeProfileBySpec[key]
    if not profileName then
        profileName = self:GetDefaultProfileName()
        self.db.char.activeProfileBySpec[key] = profileName
    end
    
    if not self.db.char.profiles[profileName] then
        self.db.char.profiles[profileName] = {
            rules = {
                { stat = "STAT_ILVL", enabled = true, op = "MAX", value = 0 },
                { stat = "STAT_HASTE", enabled = true, op = "MAX", value = 0 },
                { stat = "STAT_VERSATILITY", enabled = true, op = "MAX", value = 0 },
                { stat = "STAT_CRIT", enabled = true, op = "MAX", value = 0 },
                { stat = "STAT_MASTERY", enabled = true, op = "MAX", value = 0 },
                { stat = "STAT_LEECH", enabled = false, op = "MAX", value = 0 },
                { stat = "STAT_AVOIDANCE", enabled = false, op = "MAX", value = 0 },
                { stat = "STAT_SPEED", enabled = false, op = "MAX", value = 0 },
            },
            lockedSlots = {}
        }
    end
    
    self.activeProfile = self.db.char.profiles[profileName]
    self:ValidateAndMigrateProfile()
    
    -- Trigger UI update if window is open
    if self.UI and self.UI:IsWindowOpen() then
        self.UI:Refresh()
    end
end

function EquipOptimizer:ExportProfileToString()
    if not self.activeProfile or not self.activeProfile.rules then return "" end
    local rules = self.activeProfile.rules
    local parts = {}
    for _, rule in ipairs(rules) do
        local enabledVal = rule.enabled and "1" or "0"
        table.insert(parts, string.format("%s:%s:%s:%s", rule.stat, enabledVal, rule.op or "MAX", tostring(rule.value or 0)))
    end
    return "eo1:" .. table.concat(parts, ";")
end

function EquipOptimizer:ImportProfileFromString(str)
    if not str or not str:find("^eo1:") then
        return false, "Invalid format"
    end
    if not self.activeProfile then
        return false, "No active profile"
    end
    
    local content = str:sub(5)
    local newRules = {}
    
    for part in string.gmatch(content, "[^;]+") do
        local stat, enabledStr, op, valStr = string.match(part, "([^:]+):([^:]+):([^:]+):([^:]+)")
        if stat and enabledStr and op and valStr then
            local val = tonumber(valStr) or 0
            local enabled = (enabledStr == "1")
            if op == "max" or op == "MAX" then
                op = "MAX"
            elseif op == ">=" then
                op = ">="
            else
                if op == "min" or op == "MIN" then
                    op = "MAX"
                else
                    op = ">="
                end
            end
            table.insert(newRules, {
                stat = stat,
                enabled = enabled,
                op = op,
                value = val
            })
        else
            return false, "Invalid rule format"
        end
    end
    
    local requiredStats = { "STAT_ILVL", "STAT_HASTE", "STAT_VERSATILITY", "STAT_CRIT", "STAT_MASTERY", "STAT_LEECH", "STAT_AVOIDANCE", "STAT_SPEED" }
    
    if newRules[1] and newRules[1].stat ~= "STAT_ILVL" then
        local ilvlIdx = nil
        for i, r in ipairs(newRules) do
            if r.stat == "STAT_ILVL" then
                ilvlIdx = i
                break
            end
        end
        if ilvlIdx then
            local r = table.remove(newRules, ilvlIdx)
            table.insert(newRules, 1, r)
        else
            table.insert(newRules, 1, { stat = "STAT_ILVL", enabled = true, op = "MAX", value = 0 })
        end
    end
    
    for _, reqStat in ipairs(requiredStats) do
        local found = false
        for _, r in ipairs(newRules) do
            if r.stat == reqStat then
                found = true
                break
            end
        end
        if not found then
            table.insert(newRules, { stat = reqStat, enabled = false, op = "MAX", value = 0 })
        end
    end
    
    self.activeProfile.rules = newRules
    self:ValidateAndMigrateProfile()
    return true
end

function EquipOptimizer:OnPlayerEnteringWorld(event)
    self:UpdateProfile()
    self:CreateMinimapButton()
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

function EquipOptimizer:CreateMinimapButton()
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
    MinimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    MinimapButton:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    
    MinimapButton:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)
    
    MinimapButton:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx * scale, cy * scale
            local angle = math.atan2(y - cy, x - cx)
            local angleDeg = math.deg(angle)
            if self.isDragging then
                EquipOptimizer.db.profile.minimap.minimapAngle = angleDeg
                UpdatePosition(angleDeg)
            end
        end
    end)
    
    MinimapButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local recs = addonTable.ItemEvaluator:Optimize()
            addonTable.ItemEvaluator:EquipRecommended(recs)
        else
            EquipOptimizer:ToggleWindow()
        end
    end)
    
    MinimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("EquipOptimizer")
        GameTooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT or "ЛКМ: Открыть настройки", 1, 1, 1)
        GameTooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT or "ПКМ: Надеть лучшее снаряжение", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    MinimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    self.MinimapButton = MinimapButton
    
    -- Init position
    local angle = self.db.profile.minimap.minimapAngle or 45
    UpdatePosition(angle)
end
