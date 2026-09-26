--[[
    slots.lua
    Slot frames (icon, count, border, rarity glow, quest glow), created on
    demand; ghost placeholders for resize. UpdateSlotFrame refreshes one slot;
    ApplySearchFilter dims by search text. Exports: slots, SLOT_W/H, GAP,
    BORDER_NORMAL, FAMILY_COLORS. Depends: SmoeBag.grid, layout, helpers.
]]

SmoeBag = SmoeBag or {}

local SLOT_W = 44
local SLOT_H = 44
local GAP = 1
local ICON_PAD = 4
local HL_TEX_INSET = 0.12
local HL_R = 0.85
local HL_G = 0.90
local HL_B = 1.00
local HL_A = 1.00
local DOUBLE_CLICK_EQUIP_WINDOW = 0.35

-- Border constants
local BORDER_THICK = 1
local BORDER_INSET = 1
local BORDER_NORMAL = { 0.10, 0.10, 0.10, 0.0 }

-- Bag family colors
local FAMILY_COLORS = {
    { mask = 0x01, col = { 0.10, 0.85, 1.00, 1.00 } }, -- Quiver
    { mask = 0x02, col = { 0.10, 0.85, 0.80, 0.65 } }, -- Ammo
    { mask = 0x04, col = { 0.75, 0.30, 1.00, 1.00 } }, -- Soul
    { mask = 0x08, col = { 0.20, 1.00, 0.35, 1.00 } }, -- Herb
    { mask = 0x10, col = { 0.20, 0.60, 1.00, 1.00 } }, -- Enchant
    { mask = 0x20, col = { 1.00, 0.70, 0.20, 1.00 } }, -- Engineering
    { mask = 0x40, col = { 1.00, 0.90, 0.20, 1.00 } }, -- Keys/misc
}

-- Rarity Colors (Classic / TBC / Wrath compatible)
local RARITY_COLORS = {
    [0] = {0.62, 0.62, 0.62, 1.00}, -- Poor          grau
    [1] = {1.00, 1.00, 1.00, 1.00}, -- Common        weiß
    [2] = {0.12, 1.00, 0.00, 1.00}, -- Uncommon      grün
    [3] = {0.00, 0.44, 0.87, 1.00}, -- Rare          blau
    [4] = {0.64, 0.21, 0.93, 1.00}, -- Epic          lila
    [5] = {1.00, 0.50, 0.00, 1.00}, -- Legendary     orange
    [6] = {0.90, 0.00, 0.13, 1.00}, -- Artifact      rot
    [7] = {0.90, 0.80, 0.50, 1.00}, -- Heirloom      gold
    [8] = {0.00, 0.63, 1.00, 1.00}, -- WoW Token     hellblau
}

-- Special color for quest items (distinct brownish orange)
local QUEST_COLOR = { 0.90, 0.55, 0.15, 1.00 }

local slots = {}
SmoeBag.slots = slots
local ghosts = {}

local function EnsureGhost(i)
    if ghosts[i] then return ghosts[i] end
    local g = SmoeBag.grid:CreateTexture(nil, "BACKGROUND")
    g:SetTexture("Interface/Buttons/WHITE8X8")
    g:SetVertexColor(0.1, 0.1, 0.1, 0.5)
    ghosts[i] = g
    return g
end

function SmoeBag.EnsureGhost(i)
    return EnsureGhost(i)
end

function SmoeBag.GetGhosts()
    return ghosts
end

function SmoeBag.SetBorderColor(slotFrame, rgba)
    if not slotFrame._borderLines then return end
    for _, tex in ipairs(slotFrame._borderLines) do
        tex:SetVertexColor(rgba[1], rgba[2], rgba[3], rgba[4])
        tex:Show()
    end
end

function SmoeBag.EnsureSlot(i)
    if slots[i] then return slots[i] end

    local w = SmoeBag.SLOT_W or SLOT_W
    local h = SmoeBag.SLOT_H or SLOT_H
    local s = CreateFrame("Frame", nil, SmoeBag.grid, "BackdropTemplate")
    s:SetSize(w, h)
    s:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    s:SetBackdropColor(0, 0, 0, 0.6)

    local bf = CreateFrame("Frame", nil, s)
    bf:SetAllPoints()
    bf:SetFrameLevel(s:GetFrameLevel() + 80)

    local function mkLine()
        local t = bf:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface/Buttons/WHITE8X8")
        t:SetAlpha(1)
        return t
    end

    local inset = BORDER_INSET

    local top = mkLine()
    top:SetPoint("TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", -inset, -inset)
    top:SetHeight(BORDER_THICK)

    local bottom = mkLine()
    bottom:SetPoint("BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(BORDER_THICK)

    local left = mkLine()
    left:SetPoint("TOPLEFT", inset, -inset)
    left:SetPoint("BOTTOMLEFT", inset, inset)
    left:SetWidth(BORDER_THICK)

    local right = mkLine()
    right:SetPoint("TOPRIGHT", -inset, -inset)
    right:SetPoint("BOTTOMRIGHT", -inset, inset)
    right:SetWidth(BORDER_THICK)

    s._borderLines = { top, bottom, left, right }
    SmoeBag.SetBorderColor(s, BORDER_NORMAL)

    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetPoint("TOPLEFT", ICON_PAD, -ICON_PAD)
    s.icon:SetPoint("BOTTOMRIGHT", -ICON_PAD, ICON_PAD)
    s.icon:SetTexCoord(0.10, 0.90, 0.10, 0.90)
    s.icon:Hide()

    s.count = s:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    s.count:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Rarity Glow & Overlay
    s.rarityGlow = s:CreateTexture(nil, "ARTWORK", nil, 2)
    s.rarityGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    s.rarityGlow:SetPoint("CENTER", s.icon, "CENTER", 0, 0)
    s.rarityGlow:SetSize(w + 14, h + 14)
    s.rarityGlow:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    s.rarityGlow:SetBlendMode("ADD")
    s.rarityGlow:SetAlpha(0)
    s.rarityGlow:Hide()

    s.rarityOverlay = s:CreateTexture(nil, "OVERLAY", nil, 1)
    s.rarityOverlay:SetAllPoints(s.icon)
    s.rarityOverlay:SetColorTexture(1, 1, 1)
    s.rarityOverlay:SetAlpha(0)
    s.rarityOverlay:Hide()

    local o = CreateFrame("Button", nil, s, "SecureActionButtonTemplate")
    o:SetAllPoints()
    o:EnableMouse(true)
    -- Secure actions fire on mouse-up in current clients; custom logic runs on down only.
    o:RegisterForClicks("AnyDown", "AnyUp")
    o:RegisterForDrag("LeftButton")
    o:SetFrameLevel(s:GetFrameLevel() + 50)
    o._slot = s

    o:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
    local ht = o:GetHighlightTexture()
    if ht then
        ht:SetAllPoints(o)
        ht:SetVertexColor(HL_R, HL_G, HL_B, HL_A)
        ht:SetTexCoord(HL_TEX_INSET, 1 - HL_TEX_INSET, HL_TEX_INSET, 1 - HL_TEX_INSET)
    end

    o:SetScript("OnEnter", function(self)
        local sl = self._slot
        if not sl then return end
        SmoeBag.ShowTooltip(self, sl.bag, sl.slot)
    end)
    o:SetScript("OnLeave", GameTooltip_Hide)

    o:SetScript("PreClick", function(self, btn, down)
        if not down then return end
        local sl = self._slot
        if not sl then return end
        if btn == "LeftButton" then
            local now = (GetTime and GetTime()) or 0
            if CursorHasItem and CursorHasItem() then
                local canAutoEquip =
                    self._lastPickupTime and
                    (now - self._lastPickupTime) <= DOUBLE_CLICK_EQUIP_WINDOW and
                    self._lastPickupBag == sl.bag and
                    self._lastPickupSlot == sl.slot and
                    SmoeBag.IsEquippableLink(self._lastPickupLink) and
                    AutoEquipCursorItem

                if canAutoEquip then
                    AutoEquipCursorItem()
                    self._lastPickupTime = nil
                    self._lastPickupBag = nil
                    self._lastPickupSlot = nil
                    self._lastPickupLink = nil
                    return
                end

                self._lastPickupTime = nil
                self._lastPickupBag = nil
                self._lastPickupSlot = nil
                self._lastPickupLink = nil
                SmoeBag.PickupSlot(sl.bag, sl.slot)
                return
            end
            -- Secure path for spell targeting (e.g. Feed Pet):
            -- let SecureActionButton execute "use item from bag slot".
            if SpellIsTargeting and SpellIsTargeting() then
                self:SetAttribute("type1", "item")
                self:SetAttribute("bag1", sl.bag)
                self:SetAttribute("slot1", sl.slot)
                self:SetAttribute("item1", nil)
                return
            end
            self:SetAttribute("type1", nil)
            self:SetAttribute("bag1", nil)
            self:SetAttribute("slot1", nil)
            self:SetAttribute("item1", nil)
            self._lastPickupTime = now
            self._lastPickupBag = sl.bag
            self._lastPickupSlot = sl.slot
            self._lastPickupLink = SmoeBag.GetItemLinkSafe(sl.bag, sl.slot)
            SmoeBag.PickupSlot(sl.bag, sl.slot)
        end
    end)

    o:SetScript("OnDragStart", function(self)
        local sl = self._slot
        if not sl then return end
        if CursorHasItem and CursorHasItem() then return end
        SmoeBag.PickupSlot(sl.bag, sl.slot)
    end)

    o:SetScript("OnReceiveDrag", function(self)
        local sl = self._slot
        if not sl then return end
        if CursorHasItem and CursorHasItem() then
            SmoeBag.PickupSlot(sl.bag, sl.slot)
        end
    end)

    s.overlay = o
    slots[i] = s
    return s
end

function SmoeBag.SetSecureUse(slot, itemID)
    local o = slot.overlay
    if itemID then
        o:SetAttribute("type2", "item")
        o:SetAttribute("item2", "item:" .. itemID)
    else
        o:SetAttribute("type2", nil)
        o:SetAttribute("item2", nil)
    end
end

function SmoeBag.ApplySearchFilter(s, itemInfo)
    local searchText = SmoeBag.GetSearchText()
    if searchText == "" then 
        s:SetAlpha(1) 
        return 
    end
    if not itemInfo or not itemInfo.name then 
        s:SetAlpha(SmoeBag.SEARCH_DIM_ALPHA or 0.18) 
        return 
    end
    local name = itemInfo.name:lower()
    local itemType = (itemInfo.itemType or ""):lower()
    local subType = (itemInfo.subType or ""):lower()
    if name:find(searchText, 1, true) or itemType:find(searchText, 1, true) or subType:find(searchText, 1, true) then
        s:SetAlpha(1)
    else
        s:SetAlpha(SmoeBag.SEARCH_DIM_ALPHA or 0.18)
    end
end

function SmoeBag.UpdateSlotFrame(i)
    local layout = SmoeBag.layout
    if not layout then return end
    
    local s = slots[i]
    local e = layout[i]
    if not s or not e then return end

    local family = SmoeBag.GetBagFamilySafe(e.bag)
    SmoeBag.SetBorderColor(s, SmoeBag.FamilyToColor(family))

    local it = SmoeBag.GetItemInfoSafe(e.bag, e.slot)
    local icon = it and it.iconFileID
    local count = it and it.stackCount or 0
    local link = (it and it.hyperlink) or SmoeBag.GetItemLinkSafe(e.bag, e.slot)
    local itemID = SmoeBag.ItemIDFromLink(link)

    -- Rarity
    local quality = 1
    local isQuest = false

    if link then
        local _, _, q, _, _, itemType = SmoeBag.GetItemInfo(link)
        if q then quality = q end
        -- Simple quest detection: itemType is usually "Quest" on EN clients
        if itemType == "Quest" then
            isQuest = true
        end
    end

    local col
    if isQuest then
        col = QUEST_COLOR
    else
        col = RARITY_COLORS[quality] or RARITY_COLORS[1]
    end

    if not icon then
        s.rarityGlow:Hide()
        s.rarityOverlay:Hide()
    else
        -- Show glow for uncommon+ OR any quest item
        if col and (quality >= 2 or isQuest) then
            s.rarityGlow:SetVertexColor(col[1], col[2], col[3], col[4])
            s.rarityGlow:SetAlpha(1.0)
            s.rarityGlow:Show()
        else
            s.rarityGlow:Hide()
        end

        if col and (quality >= 2 or isQuest) then
            s.rarityOverlay:SetVertexColor(col[1], col[2], col[3], 0.11)
            s.rarityOverlay:Show()
        else
            s.rarityOverlay:Hide()
        end
    end

    if icon then 
        s.icon:SetTexture(icon) 
        s.icon:Show() 
    else 
        s.icon:Hide() 
    end
    s.count:SetText(count > 1 and count or "")
    SmoeBag.SetSecureUse(s, itemID)

    if link ~= s._lastLink then
        s._lastLink = link
        s._itemInfo = nil
    end
    if link and not s._itemInfo then
        local name, _, _, _, _, itemType, subType = SmoeBag.GetItemInfo(link)
        if name then
            s._itemInfo = { name = name, itemType = itemType, subType = subType }
        end
    end
    SmoeBag.ApplySearchFilter(s, s._itemInfo)
end

-- Export constants for other modules
SmoeBag.SLOT_W = SmoeBag.SLOT_W or SLOT_W
SmoeBag.SLOT_H = SmoeBag.SLOT_H or SLOT_H
SmoeBag.GAP = SmoeBag.GAP
if SmoeBag.GAP == nil then
    SmoeBag.GAP = GAP
end
SmoeBag.BORDER_NORMAL = BORDER_NORMAL
SmoeBag.FAMILY_COLORS = FAMILY_COLORS
