--[[
    config_ui.lua
    Config panel with live preview. Only saves to SmoeBagDB when user
    clicks Apply; Cancel restores previous values. All UI text in English.
]]

SmoeBag = SmoeBag or {}

local MIN_COLS = 4
local MAX_COLS = 20
local MIN_SLOT = 20
local MAX_SLOT = 100
local SLOT_STEP = 1
local MIN_GAP = -2
local MAX_GAP = 8
local GAP_STEP = 0.25
local DEFAULT_SLOT = 44
local DEFAULT_GAP = 1

local backupCols, backupSlotSize, backupGap
local cfg
local colSlider, colValueLabel
local slotSlider, slotValueLabel
local gapSlider, gapValueLabel

local function refreshLayout()
    SmoeBag.SetLayoutDirty(true)
    if SmoeBag.MarkDirtyAll then
        SmoeBag.MarkDirtyAll()
    end
end

local function applyColsToLive(cols)
    cols = math.floor(cols)
    cols = math.max(MIN_COLS, math.min(MAX_COLS, cols))
    SmoeBag.userCols = cols
    if colValueLabel then colValueLabel:SetText(tostring(cols)) end
    if colSlider and colSlider.SetValue then colSlider:SetValue(cols) end
    refreshLayout()
end

local function applySlotSizeToLive(sz)
    sz = math.floor(sz + 0.5)
    sz = math.max(MIN_SLOT, math.min(MAX_SLOT, sz))
    SmoeBag.SLOT_W = sz
    SmoeBag.SLOT_H = sz
    if slotValueLabel then slotValueLabel:SetText(tostring(sz)) end
    if slotSlider and slotSlider.SetValue then slotSlider:SetValue(sz) end
    refreshLayout()
end

local function formatGap(g)
    if g == math.floor(g) then
        return tostring(math.floor(g))
    end
    return string.format("%.2f", g)
end

local function applyGapToLive(g)
    g = math.max(MIN_GAP, math.min(MAX_GAP, g))
    SmoeBag.GAP = g
    if gapValueLabel then gapValueLabel:SetText(formatGap(g)) end
    if gapSlider and gapSlider.SetValue then gapSlider:SetValue(g) end
    refreshLayout()
end

local function onColSliderChange(self, value)
    applyColsToLive(math.floor(value + 0.5))
end

local function onSlotSliderChange(self, value)
    applySlotSizeToLive(value)
end

local function onGapSliderChange(self, value)
    applyGapToLive(value)
end

function SmoeBag.OpenConfig()
    if not cfg then
        SmoeBag.CreateConfigFrame()
    end
    if SmoeBag.frame and not SmoeBag.frame:IsShown() and SmoeBag.Show then
        SmoeBag.Show()
    end
    backupCols = SmoeBag.userCols
    backupSlotSize = SmoeBag.SLOT_W or DEFAULT_SLOT
    backupGap = SmoeBag.GAP or DEFAULT_GAP
    if colSlider then
        colSlider:SetValue(backupCols)
        colValueLabel:SetText(tostring(backupCols))
    end
    if slotSlider then
        slotSlider:SetValue(backupSlotSize)
        slotValueLabel:SetText(tostring(backupSlotSize))
    end
    if gapSlider then
        gapSlider:SetValue(backupGap)
        gapValueLabel:SetText(formatGap(backupGap))
    end
    cfg:Show()
end

function SmoeBag.CloseConfig(save)
    if not cfg then return end
    if save then
        SmoeBagDB.cols = SmoeBag.userCols
        SmoeBagDB.slotSize = SmoeBag.SLOT_W
        SmoeBagDB.gap = SmoeBag.GAP
    else
        SmoeBag.userCols = backupCols
        SmoeBag.SLOT_W = backupSlotSize
        SmoeBag.SLOT_H = backupSlotSize
        SmoeBag.GAP = backupGap
        refreshLayout()
    end
    cfg:Hide()
end

local function makeSliderRow(parent, y, labelText, minVal, maxVal, step, value, valueLabelRef, onChange)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(280, 24)
    row:SetPoint("TOP", 0, y)
    local lab = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lab:SetPoint("LEFT", row, "LEFT", 0, 0)
    lab:SetText(labelText)
    local sl = CreateFrame("Slider", nil, row)
    sl:SetSize(140, 17)
    sl:SetPoint("LEFT", row, "LEFT", 70, 0)
    sl:SetOrientation("HORIZONTAL")
    sl:SetMinMaxValues(minVal, maxVal)
    sl:SetValueStep(step)
    sl:SetValue(value)
    sl:SetObeyStepOnDrag(true)
    local track = sl:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    track:SetHeight(6)
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    sl:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
    local vl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    vl:SetPoint("LEFT", sl, "RIGHT", 12, 0)
    vl:SetText(tostring(value))
    if valueLabelRef then valueLabelRef[1] = vl end
    sl:SetScript("OnValueChanged", onChange)
    return sl
end

function SmoeBag.CreateConfigFrame()
    cfg = CreateFrame("Frame", "SmoeBagConfigFrame", UIParent, "BackdropTemplate")
    cfg:SetFrameStrata("FULLSCREEN_DIALOG")
    cfg:SetSize(320, 200)
    cfg:SetPoint("CENTER")
    cfg:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    cfg:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    cfg:EnableMouse(true)
    cfg:SetMovable(true)
    cfg:RegisterForDrag("LeftButton")
    cfg:SetScript("OnDragStart", cfg.StartMoving)
    cfg:SetScript("OnDragStop", cfg.StopMovingOrSizing)

    local title = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("SmoeBag Options")

    local colValRef = {}
    colSlider = makeSliderRow(cfg, -38, "Columns:", MIN_COLS, MAX_COLS, 1,
        SmoeBag.userCols or SmoeBag.COLS or 10, colValRef, onColSliderChange)
    colValueLabel = colValRef[1]

    local slotValRef = {}
    slotSlider = makeSliderRow(cfg, -66, "Slot size:", MIN_SLOT, MAX_SLOT, SLOT_STEP,
        SmoeBag.SLOT_W or DEFAULT_SLOT, slotValRef, onSlotSliderChange)
    slotValueLabel = slotValRef[1]

    local gapValRef = {}
    gapSlider = makeSliderRow(cfg, -94, "Gap:", MIN_GAP, MAX_GAP, GAP_STEP,
        SmoeBag.GAP or DEFAULT_GAP, gapValRef, onGapSliderChange)
    gapValueLabel = gapValRef[1]
    if gapValueLabel then
        gapValueLabel:SetText(formatGap(SmoeBag.GAP or DEFAULT_GAP))
    end

    local btnW, btnH = 80, 22
    local cancelBtn = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
    cancelBtn:SetSize(btnW, btnH)
    cancelBtn:SetPoint("BOTTOM", 45, 14)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        SmoeBag.CloseConfig(false)
    end)

    local applyBtn = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
    applyBtn:SetSize(btnW, btnH)
    applyBtn:SetPoint("BOTTOM", -45, 14)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        SmoeBag.CloseConfig(true)
    end)

    cfg:SetScript("OnShow", function()
        backupCols = SmoeBag.userCols
        backupSlotSize = SmoeBag.SLOT_W or DEFAULT_SLOT
        backupGap = SmoeBag.GAP or DEFAULT_GAP
    end)
    cfg:Hide()
end

-- Slash command
SLASH_SMOEBAGCONFIG1 = "/smoebagconfig"
SLASH_SMOEBAGCONFIG2 = "/smoebag config"
SlashCmdList["SMOEBAGCONFIG"] = function()
    SmoeBag.OpenConfig()
end
