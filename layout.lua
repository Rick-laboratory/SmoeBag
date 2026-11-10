--[[
    layout.lua
    Rebuilds grid from bag slot counts and userCols: layout[] = {bag, slot},
    bagStart, SizeForTiles, ComputeColsFromWidth. RebuildLayoutIfNeeded only
    runs when layout key or layoutDirty changes. UpdateAll/UpdateBag refresh
    slots. Depends: frame, grid, slots, SmoeBag.userCols.
]]

SmoeBag = SmoeBag or {}

local MIN_COLS = SmoeBag.SETTINGS.minCols
local MAX_COLS = SmoeBag.SETTINGS.maxCols
local MIN_ROWS = 2

local layout = {}
local bagSlots = {}
local bagStart = {}
local lastLayoutKey = nil
local layoutDirty = false

SmoeBag.layout = layout
SmoeBag.bagSlots = bagSlots
SmoeBag.bagStart = bagStart

function SmoeBag.GetLayoutDirty()
    return layoutDirty
end

function SmoeBag.SetLayoutDirty(value)
    layoutDirty = value
end

function SmoeBag.MakeLayoutKey()
    local max = NUM_BAG_SLOTS or 4
    local parts = {}
    parts[#parts + 1] = "cols:" .. tostring(SmoeBag.userCols)
    parts[#parts + 1] = "max:" .. tostring(max)
    for bag = 0, max do
        parts[#parts + 1] = bag .. ":" .. tostring(SmoeBag.GetNumSlots(bag))
    end
    return table.concat(parts, "|")
end

function SmoeBag.RowsFor(total, cols)
    if total <= 0 then return 1 end
    cols = math.max(1, cols)
    return math.ceil(total / cols)
end

function SmoeBag.SizeForTiles(cols, rows)
    local w = cols * (SmoeBag.SLOT_W or 44) + (cols - 1) * (SmoeBag.GAP or 1)
    local h = rows * (SmoeBag.SLOT_H or 44) + (rows - 1) * (SmoeBag.GAP or 1)
    local fw = w + (SmoeBag.OUTER_PAD or 7) * 2
    local fh = (SmoeBag.TITLE_H or 20) + (SmoeBag.GRID_TOP_PAD or 12) + h + (SmoeBag.OUTER_PAD or 7) + (SmoeBag.FOOTER_H or 22) + (SmoeBag.GAP or 1)
    return fw, fh
end

function SmoeBag.ComputeColsFromWidth(total, targetW)
    local innerW = targetW - ((SmoeBag.OUTER_PAD or 7) * 2)
    local step = ((SmoeBag.SLOT_W or 44) + (SmoeBag.GAP or 1))
    local cols = math.floor((innerW + (SmoeBag.GAP or 1) + step * 0.5) / step)
    cols = math.max(1, cols)
    cols = math.min(cols, total)
    cols = SmoeBag.Clamp(cols, MIN_COLS, MAX_COLS)
    return cols
end

function SmoeBag.RebuildLayoutIfNeeded(force)
    local key = SmoeBag.MakeLayoutKey()
    if (not force) and key == lastLayoutKey and (not layoutDirty) then
        return false
    end

    lastLayoutKey = key
    layoutDirty = false

    wipe(layout)
    wipe(bagStart)

    local total = 0
    local max = NUM_BAG_SLOTS or 4

    for bag = 0, max do
        local n = SmoeBag.GetNumSlots(bag)
        bagSlots[bag] = n
        bagStart[bag] = total + 1
        for slot = 1, n do
            total = total + 1
            layout[total] = { bag = bag, slot = slot }
        end
    end

    local cols = math.min(SmoeBag.userCols, total)
    cols = math.max(1, cols)

    local rows = (total > 0) and math.ceil(total / cols) or 1
    rows = math.max(rows, MIN_ROWS)

    local fw, fh = SmoeBag.SizeForTiles(cols, rows)

    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if sw and sh then
        local maxW = sw - (SmoeBag.SCREEN_PAD or 6) * 2
        local maxH = sh - (SmoeBag.SCREEN_PAD or 6) * 2
        if fw > maxW then fw = maxW end
        if fh > maxH then fh = maxH end
        if fw < 120 then fw = 120 end
        if fh < 120 then fh = 120 end
    end

    SmoeBag.frame:SetSize(fw, fh)

    SmoeBag.PixelSnapSize(SmoeBag.frame)
    SmoeBag.PixelSnapFrame(SmoeBag.frame)
    SmoeBag.ClampFrameToScreen(SmoeBag.frame, SmoeBag.SCREEN_PAD or 6)
    SmoeBag.PixelSnapFrame(SmoeBag.frame)

    if SmoeBag.UpdateHeaderLayout then
        SmoeBag.UpdateHeaderLayout()
    end

    local slotW = SmoeBag.SLOT_W or 44
    local slotH = SmoeBag.SLOT_H or 44
    local gap = SmoeBag.GAP or 1
    for i = 1, total do
        local s = SmoeBag.EnsureSlot(i)
        local e = layout[i]
        s.bag = e.bag
        s.slot = e.slot

        s:SetSize(slotW, slotH)
        if s.rarityGlow then
            s.rarityGlow:SetSize(slotW + 14, slotH + 14)
        end

        local c = (i - 1) % cols
        local r = math.floor((i - 1) / cols)

        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", SmoeBag.grid, "TOPLEFT",
            c * (slotW + gap),
            -r * (slotH + gap))
        s:Show()
    end

    for i = total + 1, #SmoeBag.slots do
        SmoeBag.slots[i]:Hide()
    end

    if SmoeBag.resizeBtn then
        SmoeBag.resizeBtn:ClearAllPoints()
        SmoeBag.resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    end

    if SmoeBag.UpdateFooter then
        SmoeBag.UpdateFooter()
    end
    return true
end

function SmoeBag.UpdateAll()
    for i = 1, #layout do
        SmoeBag.UpdateSlotFrame(i)
    end
    if SmoeBag.UpdateFooter then
        SmoeBag.UpdateFooter()
    end
end

function SmoeBag.UpdateBag(bag)
    if not bagStart[bag] then
        if SmoeBag.MarkDirtyAll then
            SmoeBag.MarkDirtyAll()
        end
        return
    end
    local start = bagStart[bag]
    local n = SmoeBag.GetNumSlots(bag)
    if (bagSlots[bag] or 0) ~= n then
        layoutDirty = true
        if SmoeBag.MarkDirtyAll then
            SmoeBag.MarkDirtyAll()
        end
        return
    end
    for slot = 1, n do
        SmoeBag.UpdateSlotFrame(start + (slot - 1))
    end
end
