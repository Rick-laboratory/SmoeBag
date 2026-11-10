--[[
    ui_search.lua
    Search editbox, placeholder, focus/blur and click-outside behaviour.
    Also provides UpdateHeaderLayout (search + sort button placement).
    Depends: SmoeBag.frame, SmoeBag.cleanBtn (set by sort.lua).
]]

SmoeBag = SmoeBag or {}

local SEARCH_W = 173
local SEARCH_H = 22
local SEARCH_MIN_W = 80
local SEARCH_MAX_W = 420
local SEARCH_DIM_ALPHA = 0.18
local SEARCH_BG = { 0.02, 0.02, 0.02, 0.50 }
local SEARCH_EDGE = { 0.38, 0.38, 0.38, 0.80 }
local SEARCH_IDLE_UNFOCUS = 2.2

-- Header spacing
local HEADER_LEFT_PAD = 12
local HEADER_RIGHT_PAD = 40
local HEADER_BTN_GAP = 6
local HEADER_MIN_TITLE_SPACE = 100

-- Search state variables
local searchText = ""
local searchIdle = 0
local searchFocused = false
local prevLDown, prevRDown = false, false

local search = CreateFrame("EditBox", nil, SmoeBag.frame, "BackdropTemplate")
SmoeBag.searchBox = search

search:SetSize(SEARCH_W, SEARCH_H)
search:SetPoint("TOPRIGHT", -HEADER_RIGHT_PAD, -8)
search:SetAutoFocus(false)
search:SetMaxLetters(64)

search:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
search:SetBackdropColor(SEARCH_BG[1], SEARCH_BG[2], SEARCH_BG[3], SEARCH_BG[4])
search:SetBackdropBorderColor(SEARCH_EDGE[1], SEARCH_EDGE[2], SEARCH_EDGE[3], SEARCH_EDGE[4])

search:SetFontObject("GameFontHighlightSmall")
search:SetTextInsets(6, 6, 2, 2)
search:EnableMouse(true)

local ph = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
ph:SetPoint("LEFT", search, "LEFT", 6, 0)
ph:SetText("search...")
ph:Show()

local function UpdatePlaceholder()
    if searchText == "" then
        ph:Show()
    else
        ph:Hide()
    end
end

search:SetScript("OnEditFocusGained", function()
    searchFocused = true
    searchIdle = 0
end)

search:SetScript("OnEditFocusLost", function()
    searchFocused = false
    searchIdle = 0
end)

search:SetScript("OnTextChanged", function(self)
    searchText = (self:GetText() or ""):lower()
    UpdatePlaceholder()
    searchIdle = 0
    if SmoeBag.MarkDirtyAll then
        SmoeBag.MarkDirtyAll()
    end
end)

search:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
end)

search:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)

UpdatePlaceholder()

-- Export search functions
function SmoeBag.GetSearchText()
    return searchText
end

function SmoeBag.IsSearchFocused()
    return searchFocused
end

function SmoeBag.UpdateSearchFocus(dt)
    if not searchFocused then return end

    if (search:GetText() or "") == "" then
        searchIdle = searchIdle + dt
        if searchIdle > SEARCH_IDLE_UNFOCUS then
            search:ClearFocus()
        end
    else
        searchIdle = 0
    end
end

function SmoeBag.HandleSearchClick()
    local lDown = IsMouseButtonDown and IsMouseButtonDown("LeftButton") or false
    local rDown = IsMouseButtonDown and IsMouseButtonDown("RightButton") or false
    local lPressed = lDown and (not prevLDown)
    local rPressed = rDown and (not prevRDown)

    if searchFocused and (lPressed or rPressed) then
        if not MouseIsOver(SmoeBag.frame) then
            search:ClearFocus()
        end
    end
    prevLDown, prevRDown = lDown, rDown
end

function SmoeBag.UpdateHeaderLayout()
    if not SmoeBag.frame or not search or not SmoeBag.cleanBtn then return end

    local fw = SmoeBag.frame:GetWidth() or 0
    if fw <= 0 then return end

    local avail = fw - (HEADER_LEFT_PAD + HEADER_MIN_TITLE_SPACE) - HEADER_RIGHT_PAD
    local buttonWidth = (SmoeBag.CLEAN_W or 52) + HEADER_BTN_GAP
    if avail >= SEARCH_MIN_W + buttonWidth then
        SmoeBag.cleanBtn:Show()
        avail = avail - buttonWidth
    else
        SmoeBag.cleanBtn:Hide()
    end

    if avail < SEARCH_MIN_W then
        search:Hide()
        return
    end
    search:Show()
    local w = SmoeBag.Clamp(avail, SEARCH_MIN_W, SEARCH_MAX_W)

    search:SetWidth(w)
    search:ClearAllPoints()
    search:SetPoint("TOPRIGHT", -HEADER_RIGHT_PAD, -8)

    SmoeBag.cleanBtn:ClearAllPoints()
    SmoeBag.cleanBtn:SetPoint("TOPRIGHT", search, "TOPLEFT", -HEADER_BTN_GAP, 0)
end

-- Export constants for other modules
SmoeBag.SEARCH_DIM_ALPHA = SEARCH_DIM_ALPHA
