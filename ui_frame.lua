--[[
    ui_frame.lua
    Main bag frame, header drag, close button, title, and grid container.
    Exposes: SmoeBag.frame, SmoeBag.grid, SmoeBag.SetSuspendUpdates/GetSuspendUpdates,
    and layout constants (OUTER_PAD, TITLE_H, etc.) for other modules.
]]

SmoeBag = SmoeBag or {}

local HEADER_H = 36
local OUTER_PAD = 7
local TITLE_H = 20
local GRID_TOP_PAD = 12
local SCREEN_PAD = 6

-- Main frame
local f = CreateFrame("Frame", "SmoeBagFrame", UIParent, "BackdropTemplate")
SmoeBag.frame = f

f:SetPoint("CENTER")
f:SetFrameStrata("DIALOG")
f:SetClampedToScreen(true)

f:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
f:SetBackdropColor(0.05, 0.05, 0.05, 0.39)

tinsert(UISpecialFrames, "SmoeBagFrame")

f:Hide()
f:EnableMouse(true)
f:SetMovable(true)
f:SetResizable(true)

-- --- Drag (header only) ---
local dragging = false
local suspendUpdates = false

function SmoeBag.SetSuspendUpdates(value)
    suspendUpdates = value
end

function SmoeBag.GetSuspendUpdates()
    return suspendUpdates
end

local function CursorInHeader(self)
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    x, y = x / scale, y / scale
    local left, bottom = self:GetLeft(), self:GetBottom()
    if not left then return end
    local relY = y - bottom
    return relY >= (self:GetHeight() - HEADER_H)
end

-- Drag handlers
f:SetScript("OnMouseDown", function(self, btn)
    if btn ~= "LeftButton" then return end
    if not CursorInHeader(self) then return end
    dragging = true
    suspendUpdates = true
    self:SetClampedToScreen(false)
    self:SetFrameStrata("TOOLTIP")
    self:StartMoving()
end)

f:SetScript("OnMouseUp", function(self, btn)
    if btn ~= "LeftButton" then return end
    if not dragging then return end
    dragging = false
    suspendUpdates = false
    self:StopMovingOrSizing()
    self:SetClampedToScreen(true)
    SmoeBag.PixelSnapFrame(self)
    SmoeBag.PixelSnapSize(self)
    SmoeBag.ClampFrameToScreen(self, SCREEN_PAD)
    SmoeBag.PixelSnapFrame(self)
    self:SetFrameStrata("DIALOG")
    SmoeBagDB.posX = self:GetLeft()
    SmoeBagDB.posY = self:GetTop()
    if SmoeBag.RebuildLayoutIfNeeded then
        SmoeBag.RebuildLayoutIfNeeded(true)
    end
    if SmoeBag.UpdateAll then
        SmoeBag.UpdateAll()
    end
end)

-- --- Close, title, grid ---
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)
close:SetScript("OnClick", function()
    f:Hide()
end)

-- Title
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -10)
title:SetText("SmoeBag")

local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
info:SetPoint("TOPLEFT", 12, -34)

-- Grid: child of frame; slots and layout attach to SmoeBag.grid
local grid = CreateFrame("Frame", nil, f)
grid:SetPoint("TOPLEFT", OUTER_PAD, -(TITLE_H + GRID_TOP_PAD))
grid:SetPoint("BOTTOMRIGHT", -OUTER_PAD, OUTER_PAD + 22 + 1)  -- FOOTER_H + GAP
SmoeBag.grid = grid

-- Export constants for other modules
SmoeBag.OUTER_PAD = OUTER_PAD
SmoeBag.TITLE_H = TITLE_H
SmoeBag.GRID_TOP_PAD = GRID_TOP_PAD
SmoeBag.SCREEN_PAD = SCREEN_PAD
