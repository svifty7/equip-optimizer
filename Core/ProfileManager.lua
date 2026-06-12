-- ProfileManager.lua for EquipOptimizer
local addonName, addonTable = ...
local Core = addonTable.Core

function Core:GetDefaultProfileName()
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

function Core:ValidateAndMigrateProfile()
    local profile = self.activeProfile
    if not profile then return end
    if not profile.rules then
        profile.rules = {}
    end
    if not profile.lockedSlots then
        profile.lockedSlots = {}
    end
    if profile.gemQuality == nil or profile.gemQuality > 2 then
        profile.gemQuality = 2
    end
    if profile.metaGemPreference == nil then
        profile.metaGemPreference = 0
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

function Core:GetSpecConfigKey()
    local specIndex = GetSpecialization() or 1
    local configID = 0
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        configID = C_ClassTalents.GetActiveConfigID() or 0
    end
    return string.format("%d_%d", specIndex, configID)
end

function Core:UpdateProfile()
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
