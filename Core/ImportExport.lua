-- ImportExport.lua for EquipOptimizer
local addonName, addonTable = ...
local Core = addonTable.Core

function Core:ExportProfileToString()
    if not self.activeProfile or not self.activeProfile.rules then return "" end
    local rules = self.activeProfile.rules
    local parts = {}
    for _, rule in ipairs(rules) do
        local enabledVal = rule.enabled and "1" or "0"
        table.insert(parts, string.format("%s:%s:%s:%s", rule.stat, enabledVal, rule.op or "MAX", tostring(rule.value or 0)))
    end
    return "eo1:" .. table.concat(parts, ";")
end

function Core:ImportProfileFromString(str)
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
