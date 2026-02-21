--[[
    ui_footer.lua
    Footer bar: money (gold/silver/copper) and honor. Uses SmoeBag.frame
    and SmoeBag.OUTER_PAD; exports SmoeBag.FOOTER_H and SmoeBag.UpdateFooter.
]]

SmoeBag = SmoeBag or {}

local FOOTER_H = 22
local FOOTER_BG = { 0.02, 0.02, 0.02, 0.45 }
local FOOTER_EDGE = { 0.20, 0.20, 0.20, 0.60 }
local FOOTER_PAD_X = 10

local footer = CreateFrame("Frame", nil, SmoeBag.frame, "BackdropTemplate")
footer:SetHeight(FOOTER_H)
footer:SetPoint("BOTTOMLEFT", SmoeBag.OUTER_PAD, SmoeBag.OUTER_PAD)
footer:SetPoint("BOTTOMRIGHT", -SmoeBag.OUTER_PAD, SmoeBag.OUTER_PAD)

footer:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
footer:SetBackdropColor(FOOTER_BG[1], FOOTER_BG[2], FOOTER_BG[3], FOOTER_BG[4])
footer:SetBackdropBorderColor(FOOTER_EDGE[1], FOOTER_EDGE[2], FOOTER_EDGE[3], FOOTER_EDGE[4])

local moneyFS = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
moneyFS:SetPoint("LEFT", footer, "LEFT", FOOTER_PAD_X, 0)
moneyFS:SetJustifyH("LEFT")

-- Settings button: slightly smaller than currency icons for a slick look (~75%)
local ICON_SIZE = 14
local settingsBtn = CreateFrame("Button", nil, footer)
settingsBtn:SetSize(ICON_SIZE, ICON_SIZE)
settingsBtn:SetPoint("RIGHT", footer, "RIGHT", -FOOTER_PAD_X, 0)
settingsBtn:SetScript("OnClick", function()
    if SmoeBag.OpenConfig then
        SmoeBag.OpenConfig()
    end
end)
settingsBtn:SetScript("OnEnter", function(self)
    if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("SmoeBag Options")
        GameTooltip:Show()
    end
end)
settingsBtn:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
end)
local settingsIcon = settingsBtn:CreateTexture(nil, "ARTWORK")
settingsIcon:SetAllPoints()
settingsIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
settingsIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local honorFS = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
honorFS:SetPoint("RIGHT", settingsBtn, "LEFT", -6, 0)
honorFS:SetJustifyH("RIGHT")

-- Export constant for other modules
SmoeBag.FOOTER_H = FOOTER_H

function SmoeBag.UpdateFooter()
    local m = (type(GetMoney) == "function") and GetMoney() or 0
    moneyFS:SetText(SmoeBag.FormatMoneyInline(m))
    local honor = 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(1901)  -- Honor Points ID in TBC Classic
        honor = info and info.quantity or 0
    end
    honorFS:SetText(SmoeBag.FormatHonorInline(honor))
end
