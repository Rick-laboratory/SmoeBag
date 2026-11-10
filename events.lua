--[[
    events.lua
    PLAYER_LOGIN: position from DB, RebuildLayout, InstallOverrides.
    Show/Hide/Toggle; InstallOverrides hooks ToggleBackpack,
    OpenAllBags, CloseAllBags. BAG_UPDATE/BAG_UPDATE_DELAYED mark dirty;
    MERCHANT_SHOW opens SmoeBag; PLAYER_MONEY/CURRENCY_DISPLAY_UPDATE
    refresh footer.
]]

SmoeBag = SmoeBag or {}

local FORCE_CLOSE_BLIZZ_BAGS = true
local old_ToggleBackpack = nil
local old_ToggleAllBags = nil
local old_OpenAllBags = nil
local old_CloseAllBags = nil
local overridesInstalled = false

-- Modules can set defaults during load; normalize persisted values again at login.
SmoeBag.ApplySavedSettings()

function SmoeBag.Show()
    if FORCE_CLOSE_BLIZZ_BAGS and old_CloseAllBags then
        old_CloseAllBags()
    elseif FORCE_CLOSE_BLIZZ_BAGS and CloseAllBags then
        CloseAllBags()
    end
    SmoeBag.frame:Show()
    SmoeBag.RebuildLayoutIfNeeded(false)
    if SmoeBag.UpdateHeaderLayout then
        SmoeBag.UpdateHeaderLayout()
    end
    SmoeBag.UpdateAll()
    SmoeBag.SetBagBarChecked(true)
end

function SmoeBag.Hide()
    SmoeBag.frame:Hide()
    SmoeBag.SetBagBarChecked(false)
end

function SmoeBag.Toggle()
    if SmoeBag.frame:IsShown() then
        SmoeBag.Hide()
    else
        SmoeBag.Show()
    end
end

function SmoeBag.InstallOverrides()
    if overridesInstalled then return end

    if type(ToggleBackpack) == "function" then
        old_ToggleBackpack = ToggleBackpack
        ToggleBackpack = function()
            SmoeBag.Toggle()
        end
    end

    if type(ToggleAllBags) == "function" then
        old_ToggleAllBags = ToggleAllBags
        ToggleAllBags = function()
            SmoeBag.Toggle()
        end
    end

    if type(OpenAllBags) == "function" then
        old_OpenAllBags = OpenAllBags
        OpenAllBags = function()
            SmoeBag.Show()
        end
    end

    if type(CloseAllBags) == "function" then
        old_CloseAllBags = CloseAllBags
        CloseAllBags = function()
            SmoeBag.Hide()
        end
    end

    overridesInstalled = true
end

-- Event handler
SmoeBag.frame:RegisterEvent("PLAYER_LOGIN")
SmoeBag.frame:RegisterEvent("BAG_UPDATE_DELAYED")
SmoeBag.frame:RegisterEvent("BAG_UPDATE")
SmoeBag.frame:RegisterEvent("PLAYER_STARTED_MOVING")
SmoeBag.frame:RegisterEvent("PLAYER_MONEY")
SmoeBag.frame:RegisterEvent("MERCHANT_SHOW")
SmoeBag.frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
SmoeBag.frame:RegisterEvent("PLAYER_LOGOUT")

SmoeBag.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SmoeBag.ApplySavedSettings()
        SmoeBag.playerFaction = UnitFactionGroup("player")
        SmoeBag.frame:ClearAllPoints()
        SmoeBag.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", SmoeBagDB.posX, SmoeBagDB.posY)
        SmoeBag.RebuildLayoutIfNeeded(true)
        if SmoeBag.UpdateHeaderLayout then
            SmoeBag.UpdateHeaderLayout()
        end
        SmoeBag.UpdateAll()
        SmoeBag.InstallOverrides()
        SmoeBag.SetBagBarChecked(false)
        SmoeBag.Print("v0.62 loaded - /smoebagconfig or /smoebag config")
        return
    end

    if event == "PLAYER_MONEY" then
        if SmoeBag.frame:IsShown() then
            SmoeBag.UpdateFooter()
        end
        return
    end

    if event == "CURRENCY_DISPLAY_UPDATE" then
        if SmoeBag.frame:IsShown() then
            SmoeBag.UpdateFooter()
        end
        return
    end

    if event == "PLAYER_LOGOUT" then
        -- Defensive persistence: keep current runtime settings on relog.
        SmoeBagDB.cols = tonumber(SmoeBag.userCols) or SmoeBagDB.cols
        SmoeBagDB.slotSize = tonumber(SmoeBag.SLOT_W) or SmoeBagDB.slotSize
        SmoeBagDB.gap = tonumber(SmoeBag.GAP)
        if SmoeBagDB.gap == nil then
            SmoeBagDB.gap = 1
        end
        return
    end

    if event == "MERCHANT_SHOW" then
        if FORCE_CLOSE_BLIZZ_BAGS and old_CloseAllBags then
            old_CloseAllBags()
        elseif FORCE_CLOSE_BLIZZ_BAGS and CloseAllBags then
            CloseAllBags()
        end
        SmoeBag.Show()
        return
    end

    if event == "PLAYER_STARTED_MOVING" then
        if SmoeBag.IsSearchFocused() then
            SmoeBag.searchBox:ClearFocus()
        end
        return
    end

    if not SmoeBag.frame:IsShown() then return end

    if event == "BAG_UPDATE" then
        local bag = ...
        if type(bag) == "number" then
            local n = SmoeBag.GetNumSlots(bag)
            if (SmoeBag.bagSlots[bag] or 0) ~= n then
                SmoeBag.SetLayoutDirty(true)
                if SmoeBag.MarkDirtyAll then
                    SmoeBag.MarkDirtyAll()
                end
            else
                if SmoeBag.MarkDirtyBag then
                    SmoeBag.MarkDirtyBag(bag)
                end
            end
        else
            if SmoeBag.MarkDirtyAll then
                SmoeBag.MarkDirtyAll()
            end
        end
        return
    end

    if SmoeBag.MarkDirtyAll then
        SmoeBag.MarkDirtyAll()
    end
end)
