--[[
    main.lua
    OnUpdate: throttle, resize tick, search focus, sort tick, then
    layout/slot updates (dirtyAll vs dirtyBags). Also slash /smoebag and /smoebagclean.
    Requires: frame, grid, layout, slots, sort, search, resize, events.
]]

SmoeBag = SmoeBag or {}

local UPDATE_THROTTLE = 0.06

SmoeBag.userCols = SmoeBagDB.cols or SmoeBag.COLS

local dirtyAll = false
local dirtyBags = {}
local timer = 0

function SmoeBag.MarkDirtyAll()
    dirtyAll = true
end

function SmoeBag.MarkDirtyBag(bag)
    dirtyBags[bag] = true
end

SmoeBag.frame:SetScript("OnUpdate", function(_, dt)
    if not SmoeBag.frame:IsShown() then return end

    if SmoeBag.IsResizing() then
        SmoeBag.LiveResizeFromCursor()
    end

    SmoeBag.HandleSearchClick()

    SmoeBag.UpdateSearchFocus(dt)

    SmoeBag.CleanOnUpdate(dt)

    if SmoeBag.GetSuspendUpdates() then return end
    if (not dirtyAll) and (not next(dirtyBags)) and (not SmoeBag.GetLayoutDirty()) then return end

    timer = timer + dt
    if timer < UPDATE_THROTTLE then return end
    timer = 0

    if SmoeBag.GetLayoutDirty() then
        SmoeBag.RebuildLayoutIfNeeded(true)
        dirtyAll = true
        SmoeBag.SetLayoutDirty(false)
    end

    if dirtyAll then
        dirtyAll = false
        SmoeBag.RebuildLayoutIfNeeded(false)
        if SmoeBag.UpdateHeaderLayout then
            SmoeBag.UpdateHeaderLayout()
        end
        SmoeBag.UpdateAll()
        wipe(dirtyBags)
        return
    end

    if next(dirtyBags) then
        for bag in pairs(dirtyBags) do
            SmoeBag.UpdateBag(bag)
        end
        wipe(dirtyBags)
    end
end)

SLASH_SMOEBAG1 = "/smoebag"
SlashCmdList["SMOEBAG"] = function(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "config" then
        SmoeBag.OpenConfig()
    elseif command == "sort" then
        SmoeBag.CleanStart()
    elseif command == "" then
        SmoeBag.Toggle()
    else
        SmoeBag.Print("Usage: /smoebag [config|sort]")
    end
end

SLASH_SMOEBAGCLEAN1 = "/smoebagclean"
SlashCmdList["SMOEBAGCLEAN"] = function()
    SmoeBag.CleanStart()
end
