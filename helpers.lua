--[[
    helpers.lua
    Shared utilities: API wrappers (C_Container vs classic), tooltip, frame
    snapping/clamping, money/honor formatting, bag family → color.
    Depends: config (for FAMILY_COLORS/BORDER_NORMAL from slots.lua).
]]

SmoeBag = SmoeBag or {}

function SmoeBag.Print(...)
    local t = {}
    for i = 1, select("#", ...) do 
        t[#t + 1] = tostring(select(i, ...)) 
    end
    print("|cffffcc00SmoeBag|r", table.concat(t, " "))
end

-- API wrappers for compatibility
-- --- Container API (C_Container vs classic) ---
function SmoeBag.GetNumSlots(bag)
    if C_Container then 
        return C_Container.GetContainerNumSlots(bag) or 0 
    end
    return GetContainerNumSlots(bag) or 0
end

function SmoeBag.PickupSlot(bag, slot)
    if C_Container then 
        C_Container.PickupContainerItem(bag, slot) 
    else 
        PickupContainerItem(bag, slot) 
    end
end

function SmoeBag.UseSlot(bag, slot)
    if C_Container then
        C_Container.UseContainerItem(bag, slot)
    else
        UseContainerItem(bag, slot)
    end
end

function SmoeBag.GetItemLinkSafe(bag, slot)
    if C_Container then 
        return C_Container.GetContainerItemLink(bag, slot) 
    end
    return GetContainerItemLink(bag, slot)
end

function SmoeBag.GetItemInfoSafe(bag, slot)
    if C_Container then 
        return C_Container.GetContainerItemInfo(bag, slot) 
    end
    local texture, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
    if texture then 
        return { iconFileID = texture, stackCount = count, hyperlink = link } 
    end
end

function SmoeBag.ItemIDFromLink(link)
    if not link then return end
    local id = link:match("item:(%d+)")
    return id and tonumber(id)
end

function SmoeBag.IsEquippableLink(link)
    if not link then return false end
    if IsEquippableItem and IsEquippableItem(link) then
        return true
    end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    return equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG" or false
end

-- --- Tooltip ---
function SmoeBag.ShowTooltip(owner, bag, slot)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    if C_Container and C_Container.SetBagItem then
        C_Container.SetBagItem(GameTooltip, bag, slot)
    elseif GameTooltip.SetBagItem then
        GameTooltip:SetBagItem(bag, slot)
    end

    if GameTooltip:NumLines() == 0 then
        local link = SmoeBag.GetItemLinkSafe(bag, slot)
        if link and GameTooltip.SetHyperlink then
            GameTooltip:SetHyperlink(link)
        else
            GameTooltip:AddLine("Empty", 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:Show()
end

-- --- Frame layout (pixel snap, clamp to screen) ---
function SmoeBag.PixelSnapFrame(fr)
    local scale = fr:GetEffectiveScale()
    local left = fr:GetLeft()
    local top = fr:GetTop()
    if not left or not top then return end
    left = math.floor(left * scale + 0.5) / scale
    top = math.floor(top * scale + 0.5) / scale
    fr:ClearAllPoints()
    fr:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

function SmoeBag.PixelSnapSize(fr)
    local scale = fr:GetEffectiveScale()
    local w, h = fr:GetSize()
    if not w or not h then return end
    w = math.floor(w * scale + 0.5) / scale
    h = math.floor(h * scale + 0.5) / scale
    fr:SetSize(w, h)
end

function SmoeBag.ClampFrameToScreen(fr, pad)
    pad = pad or 0
    if not fr:IsShown() then return end

    local scale = fr:GetEffectiveScale()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if not sw or not sh then return end

    local left, right, top, bottom = fr:GetLeft(), fr:GetRight(), fr:GetTop(), fr:GetBottom()
    if not left or not right or not top or not bottom then return end

    left = left * scale
    right = right * scale
    top = top * scale
    bottom = bottom * scale

    local dx, dy = 0, 0
    if left < pad then dx = (pad - left) end
    if right > (sw * scale - pad) then dx = dx - (right - (sw * scale - pad)) end
    if top > (sh * scale - pad) then dy = dy - (top - (sh * scale - pad)) end
    if bottom < pad then dy = (pad - bottom) end

    if dx ~= 0 or dy ~= 0 then
        local curLeft = fr:GetLeft()
        local curTop = fr:GetTop()
        if curLeft and curTop then
            local nl = (curLeft * scale + dx) / scale
            local nt = (curTop * scale + dy) / scale
            fr:ClearAllPoints()
            fr:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", nl, nt)
        end
    end
end

-- --- Bag family and colors (uses SmoeBag.FAMILY_COLORS set by slots.lua) ---
function SmoeBag.GetBagFamilySafe(bag)
    local _, family
    if C_Container and C_Container.GetContainerNumFreeSlots then
        _, family = C_Container.GetContainerNumFreeSlots(bag)
    elseif GetContainerNumFreeSlots then
        _, family = GetContainerNumFreeSlots(bag)
    end
    return family or 0
end

function SmoeBag.FamilyToColor(family)
    if not family or family == 0 then 
        return SmoeBag.BORDER_NORMAL or { 0.10, 0.10, 0.10, 0.0 }
    end
    if not SmoeBag.FAMILY_COLORS then
        return SmoeBag.BORDER_NORMAL or { 0.10, 0.10, 0.10, 0.0 }
    end
    if bit and bit.band then
        for i = 1, #SmoeBag.FAMILY_COLORS do
            local e = SmoeBag.FAMILY_COLORS[i]
            if bit.band(family, e.mask) ~= 0 then 
                return e.col 
            end
        end
        return SmoeBag.BORDER_NORMAL or { 0.10, 0.10, 0.10, 0.0 }
    end
    for i = 1, #SmoeBag.FAMILY_COLORS do
        local e = SmoeBag.FAMILY_COLORS[i]
        if family == e.mask then 
            return e.col 
        end
    end
    return SmoeBag.BORDER_NORMAL or { 0.10, 0.10, 0.10, 0.0 }
end

-- --- Misc ---
function SmoeBag.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- --- Money / honor formatting ---
function SmoeBag.FormatMoneyInline(money)
    money = tonumber(money) or 0
    if money < 0 then money = 0 end
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = math.floor(money % 100)

    local gI = "|TInterface/MoneyFrame/UI-GoldIcon:0:0:2:0|t"
    local sI = "|TInterface/MoneyFrame/UI-SilverIcon:0:0:2:0|t"
    local cI = "|TInterface/MoneyFrame/UI-CopperIcon:0:0:2:0|t"

    return string.format("%d%s %d%s %d%s", gold, gI, silver, sI, copper, cI)
end

function SmoeBag.FormatHonorInline(honor)
    honor = tonumber(honor) or 0
    local hI
    if SmoeBag.playerFaction == "Alliance" then
        hI = "|TInterface\\PVPFrame\\PVP-Currency-Alliance:0:0:2:0|t"
    elseif SmoeBag.playerFaction == "Horde" then
        hI = "|TInterface\\PVPFrame\\PVP-Currency-Horde:0:0:2:0|t"
    else
        hI = "|TInterface\\PVPFrame\\PVP-HonorPoints-Icon:0:0:2:0|t"
    end
    return string.format("%d%s", honor, hI)
end
