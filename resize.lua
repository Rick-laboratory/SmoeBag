--[[
    resize.lua
    Bottom-right resize grip: drag updates frame size and column count;
    LiveResizeFromCursor shows ghost slots during drag; on release, snap and
    save userCols. Exposes: resizeBtn, IsResizing, LiveResizeFromCursor.
]]

SmoeBag = SmoeBag or {}

local RESIZE_GRIP = 14

local resizing = false
local rz_left, rz_top = nil, nil
local rz_startCX, rz_startCY = nil, nil
local rz_startW, rz_startH = nil, nil
local rz_startCols = SmoeBag.COLS or 10

function SmoeBag.ScreenUI()
    local s = UIParent:GetEffectiveScale()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    return sw, sh, s
end

function SmoeBag.LiveResizeFromCursor()
    local layout = SmoeBag.layout
    if not layout then return end
    
    local total = #layout
    if total <= 0 then return end
    if not rz_left or not rz_top then return end

    local sw, sh, scale = SmoeBag.ScreenUI()
    if sw <= 0 or sh <= 0 then return end

    local cx, cy = GetCursorPosition()
    cx = cx / scale
    cy = cy / scale

    local dx = cx - rz_startCX
    local dy = cy - rz_startCY

    local desiredW = rz_startW + dx
    local desiredH = rz_startH - dy

    local maxW = sw - (SmoeBag.SCREEN_PAD or 6) - rz_left
    local maxH = rz_top - (SmoeBag.SCREEN_PAD or 6)

    desiredW = SmoeBag.Clamp(desiredW, 120, maxW)
    desiredH = SmoeBag.Clamp(desiredH, 120, maxH)

    SmoeBag.frame:SetSize(desiredW, desiredH)
    if SmoeBag.UpdateHeaderLayout then
        SmoeBag.UpdateHeaderLayout()
    end

    if total > 0 then
        local tentative_cols = SmoeBag.ComputeColsFromWidth(total, desiredW)
        tentative_cols = math.min(tentative_cols, total)
        tentative_cols = SmoeBag.Clamp(tentative_cols, 4, 20)  -- MIN_COLS, MAX_COLS
        local tentative_rows = SmoeBag.RowsFor(total, tentative_cols)
        local ghosts = SmoeBag.GetGhosts()
        for i = 1, total do
            local g = SmoeBag.EnsureGhost(i)
            g:SetSize(SmoeBag.SLOT_W or 44, SmoeBag.SLOT_H or 44)
            local c = (i - 1) % tentative_cols
            local r = math.floor((i - 1) / tentative_cols)
            g:ClearAllPoints()
            g:SetPoint("TOPLEFT", c * ((SmoeBag.SLOT_W or 44) + (SmoeBag.GAP or 1)), -r * ((SmoeBag.SLOT_H or 44) + (SmoeBag.GAP or 1)))
            g:Show()
        end
        for i = total + 1, #ghosts do 
            if ghosts[i] then ghosts[i]:Hide() end
        end
    end
end

function SmoeBag.IsResizing()
    return resizing
end

function SmoeBag.SetResizing(value)
    resizing = value
end

local resizeBtn = CreateFrame("Button", nil, SmoeBag.frame)
resizeBtn:SetSize(RESIZE_GRIP, RESIZE_GRIP)
resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
resizeBtn:SetFrameLevel(SmoeBag.frame:GetFrameLevel() + 200)
resizeBtn:EnableMouse(true)

local rt = resizeBtn:CreateTexture(nil, "OVERLAY")
rt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
rt:SetAllPoints()
resizeBtn:SetNormalTexture(rt)

local rt2 = resizeBtn:CreateTexture(nil, "OVERLAY")
rt2:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
rt2:SetAllPoints()
resizeBtn:SetHighlightTexture(rt2)

SmoeBag.resizeBtn = resizeBtn

resizeBtn:SetScript("OnMouseDown", function(self, btn)
    if btn ~= "LeftButton" then return end
    
    resizing = true
    SmoeBag.SetSuspendUpdates(true)
    
    SmoeBag.frame:SetClampedToScreen(false)
    SmoeBag.frame:SetFrameStrata("TOOLTIP")

    rz_left = SmoeBag.frame:GetLeft()
    rz_top = SmoeBag.frame:GetTop()
    rz_startCols = SmoeBag.userCols
    local scale = SmoeBag.frame:GetEffectiveScale()
    rz_startCX, rz_startCY = GetCursorPosition()
    rz_startCX = rz_startCX / scale
    rz_startCY = rz_startCY / scale
    rz_startW = SmoeBag.frame:GetWidth()
    rz_startH = SmoeBag.frame:GetHeight()

    for i = 1, #SmoeBag.slots do 
        local s = SmoeBag.slots[i]
        if s then s:Hide() end
    end
end)

resizeBtn:SetScript("OnMouseUp", function(self, btn)
    if btn ~= "LeftButton" then return end
    if not resizing then return end

    local layout = SmoeBag.layout
    local total = layout and #layout or 0
    if total > 0 then
        local fw = SmoeBag.frame:GetWidth() or 0
        SmoeBag.userCols = SmoeBag.ComputeColsFromWidth(total, fw)
    end

    resizing = false
    SmoeBag.SetSuspendUpdates(false)
    rz_left, rz_top = nil, nil
    rz_startCX, rz_startCY = nil, nil
    rz_startW, rz_startH = nil, nil

    local ghosts = SmoeBag.GetGhosts()
    for i = 1, #ghosts do 
        if ghosts[i] then ghosts[i]:Hide() end 
    end

    SmoeBag.frame:SetClampedToScreen(true)
    SmoeBag.frame:SetFrameStrata("DIALOG")

    SmoeBag.PixelSnapSize(SmoeBag.frame)
    SmoeBag.PixelSnapFrame(SmoeBag.frame)
    SmoeBag.ClampFrameToScreen(SmoeBag.frame, SmoeBag.SCREEN_PAD or 6)
    SmoeBag.PixelSnapFrame(SmoeBag.frame)

    if SmoeBag.UpdateHeaderLayout then
        SmoeBag.UpdateHeaderLayout()
    end

    SmoeBag.SetLayoutDirty(true)
    if SmoeBag.MarkDirtyAll then
        SmoeBag.MarkDirtyAll()
    end
    SmoeBagDB.cols = SmoeBag.userCols
end)
