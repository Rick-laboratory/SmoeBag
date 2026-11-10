-- Saved settings are normalized at file load and again at PLAYER_LOGIN.
SmoeBag = SmoeBag or {}

local function finiteNumber(value, fallback)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end
    return number
end

local function bounded(value, fallback, minimum, maximum, integer)
    local number = finiteNumber(value, fallback)
    if integer then number = math.floor(number + 0.5) end
    return math.max(minimum, math.min(maximum, number))
end

function SmoeBag.ApplySavedSettings()
    if type(SmoeBagDB) ~= "table" then SmoeBagDB = {} end
    local settings = SmoeBag.SETTINGS
    SmoeBagDB.posX = finiteNumber(SmoeBagDB.posX, 0)
    SmoeBagDB.posY = finiteNumber(SmoeBagDB.posY, 0)
    SmoeBagDB.cols = bounded(SmoeBagDB.cols, SmoeBag.COLS, settings.minCols, settings.maxCols, true)
    SmoeBagDB.slotSize = bounded(SmoeBagDB.slotSize, settings.defaultSlot,
                               settings.minSlot, settings.maxSlot, true)
    SmoeBagDB.gap = bounded(SmoeBagDB.gap, settings.defaultGap, settings.minGap, settings.maxGap, false)
    SmoeBag.userCols = SmoeBagDB.cols
    SmoeBag.SLOT_W = SmoeBagDB.slotSize
    SmoeBag.SLOT_H = SmoeBagDB.slotSize
    SmoeBag.GAP = SmoeBagDB.gap
end

SmoeBag.ApplySavedSettings()
