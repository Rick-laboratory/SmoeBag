--[[
    saved_variables.lua
    SavedVariables init. Load after config.lua so SmoeBag.COLS exists.
    Persists: posX/posY (frame position). cols only when user changed it
    (via configurator or resize); otherwise default SmoeBag.COLS is used.
]]

SmoeBag = SmoeBag or {}

SmoeBagDB = SmoeBagDB or {}
SmoeBagDB.posX = tonumber(SmoeBagDB.posX) or 0
SmoeBagDB.posY = tonumber(SmoeBagDB.posY) or 0
SmoeBagDB.cols = tonumber(SmoeBagDB.cols) or SmoeBag.COLS
SmoeBagDB.slotSize = tonumber(SmoeBagDB.slotSize) or 44
SmoeBagDB.gap = tonumber(SmoeBagDB.gap)
if SmoeBagDB.gap == nil then
    SmoeBagDB.gap = 1
end

-- Apply persisted layout settings as early as possible in load order.
SmoeBag.userCols = SmoeBagDB.cols
SmoeBag.SLOT_W = SmoeBagDB.slotSize
SmoeBag.SLOT_H = SmoeBagDB.slotSize
SmoeBag.GAP = SmoeBagDB.gap
