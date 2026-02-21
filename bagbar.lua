--[[
    bagbar.lua
    Syncs default UI bag bar checked state with SmoeBag open/close
    (backpack + bag 0–3 + keyring).
]]

SmoeBag = SmoeBag or {}

function SmoeBag.SetBagBarChecked(on)
    local btns = {
        "MainMenuBarBackpackButton",
        "CharacterBag0Slot",
        "CharacterBag1Slot",
        "CharacterBag2Slot",
        "CharacterBag3Slot",
        "KeyRingButton",
    }
    for _, name in ipairs(btns) do
        local b = _G[name]
        if b and b.SetChecked then 
            b:SetChecked(on and true or false) 
        end
    end
end
