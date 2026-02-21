--[[
    config.lua
    Shared default for column count. Other modules keep their own constants
    next to where they're used; this is the one value referenced at load
    (e.g. saved_variables.lua) and by layout when restoring from DB.
]]

SmoeBag = SmoeBag or {}

SmoeBag.COLS = 10
