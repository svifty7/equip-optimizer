-- TestScoringMockData.lua
-- Contains the mock data structures used in TestScoring.lua simulation tests

local currentStats = {
    STAT_CRIT = 2070,
    STAT_HASTE = 2904,
    STAT_MASTERY = 2484,
    STAT_VERSATILITY = 810,
    STAT_LEECH = 0,
    STAT_AVOIDANCE = 0,
    STAT_SPEED = 0,
    STAT_ILVL = 600.0,
}

local ratingPerPercent = {
    STAT_CRIT = 138,
    STAT_HASTE = 132,
    STAT_MASTERY = 138,
    STAT_VERSATILITY = 162,
}

local rules = {
    { stat = "STAT_HASTE", enabled = true, op = ">=", value = 25.0 },
    { stat = "STAT_MASTERY", enabled = true, op = ">=", value = 20.0 },
    { stat = "STAT_CRIT", enabled = true, op = "MAX", value = 0 },
}

local equipped = {
    [11] = { link = "Equipped Ring 1", searchKey = "eq-11", ratings = { STAT_HASTE = 300, STAT_CRIT = 100 }, gemsAndEnchants = { STAT_HASTE = 50 }, ilvl = 600 },
    [12] = { link = "Equipped Ring 2", searchKey = "eq-12", ratings = { STAT_MASTERY = 400, STAT_VERSATILITY = 100 }, gemsAndEnchants = {}, ilvl = 600 }
}

local candidates = {
    [11] = {
        equipped[11], -- Equipped Ring 1
        { link = "Bag Ring A", searchKey = "0-1", ratings = { STAT_HASTE = 1500, STAT_CRIT = 50 }, gemsAndEnchants = { STAT_HASTE = 100 }, ilvl = 610, bag = 0, slot = 1 },
        { link = "Bag Ring B", searchKey = "0-2", ratings = { STAT_MASTERY = 600, STAT_CRIT = 200 }, gemsAndEnchants = {}, ilvl = 615, bag = 0, slot = 2 }
    },
    [12] = {
        equipped[12], -- Equipped Ring 2
        { link = "Bag Ring C", searchKey = "0-3", ratings = { STAT_HASTE = 200, STAT_MASTERY = 1200 }, gemsAndEnchants = {}, ilvl = 610, bag = 0, slot = 3 }
    }
}

return {
    currentStats = currentStats,
    ratingPerPercent = ratingPerPercent,
    rules = rules,
    equipped = equipped,
    candidates = candidates
}
