-- Run from the repository root with Lua 5.1 or a compatible interpreter.
local parsed = 0
for line in io.lines("SmoeBag.toc") do
    local file = line:match("^%s*(.-)%s*$")
    if file:match("%.lua$") then
        assert(loadfile(file))
        parsed = parsed + 1
    end
end
assert(parsed == 14, "Review the runtime-module count when the TOC changes")

dofile("config.lua")
SmoeBagDB = { cols = "-500", slotSize = 0 / 0, gap = 1 / 0, posX = "invalid" }
dofile("saved_variables.lua")
assert(SmoeBag.userCols == 4 and SmoeBag.SLOT_W == 44 and SmoeBag.GAP == 1)
assert(SmoeBagDB.posX == 0)
SmoeBagDB = { cols = 500, slotSize = "101", gap = -100, posY = -1 / 0 }
SmoeBag.ApplySavedSettings()
assert(SmoeBag.userCols == 20 and SmoeBag.SLOT_W == 100 and SmoeBag.GAP == -2)
assert(SmoeBagDB.posY == 0)
SmoeBagDB = { cols = 9.8, slotSize = 32, gap = 0 }
SmoeBag.ApplySavedSettings()
assert(SmoeBag.userCols == 10 and SmoeBag.GAP == 0)
SmoeBagDB = false
SmoeBag.ApplySavedSettings()
assert(type(SmoeBagDB) == "table" and SmoeBag.SLOT_W == 44)

dofile("helpers.lua")
C_Container = {} -- Some clients provide the namespace but not every method.
GetContainerNumSlots = function(bag) return bag + 10 end
assert(SmoeBag.GetNumSlots(2) == 12)
C_Container.GetContainerNumSlots = function() return 42 end
assert(SmoeBag.GetNumSlots(2) == 42)
local split
SplitContainerItem = function(bag, slot, amount) split = { bag, slot, amount, "legacy" } end
assert(SmoeBag.SplitSlot(1, 2, 3) and split[4] == "legacy")
C_Container.SplitContainerItem = function(bag, slot, amount) split = { bag, slot, amount, "modern" } end
assert(SmoeBag.SplitSlot(4, 5, 6) and split[1] == 4 and split[3] == 6 and split[4] == "modern")
C_Container, SplitContainerItem = nil, nil
assert(not SmoeBag.SplitSlot(1, 1, 1))
GetContainerItemInfo = function() return 100, 7, false, nil, nil, nil, "item:123:0" end
local info = SmoeBag.GetItemInfoSafe(0, 1)
assert(info.iconFileID == 100 and info.stackCount == 7 and info.hyperlink == "item:123:0")
assert(SmoeBag.ItemIDFromLink("|Hitem:123:0|hName|h") == 123)
assert(SmoeBag.ItemIDFromLink("not an item") == nil)

dofile("layout.lua")
assert(SmoeBag.RowsFor(21, 10) == 3 and SmoeBag.RowsFor(0, 10) == 1)
local width = SmoeBag.SizeForTiles(10, 4)
assert(SmoeBag.ComputeColsFromWidth(40, width) == 10)
assert(SmoeBag.ComputeColsFromWidth(40, 1e9) == 20)
assert(SmoeBag.ComputeColsFromWidth(40, -100) == 4)

local function frame()
    local value = { width = 850, shown = true, enabled = true, scripts = {} }
    function value:SetScript(event, callback) self.scripts[event] = callback end
    function value:SetSize(w, h) self.width, self.height = w, h end
    function value:SetWidth(w) self.width = w end
    function value:GetWidth() return self.width end
    function value:GetFrameLevel() return 1 end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false end
    function value:SetEnabled(enabled) self.enabled = enabled end
    function value:CreateFontString() return frame() end
    for _, method in ipairs({ "SetPoint", "SetAutoFocus", "SetMaxLetters", "SetBackdrop",
                              "SetBackdropColor", "SetBackdropBorderColor", "SetFontObject",
                              "SetTextInsets", "EnableMouse", "SetText", "ClearAllPoints",
                              "SetFrameLevel" }) do
        value[method] = function() end
    end
    return value
end
CreateFrame = function() return frame() end
SmoeBag.frame, SmoeBag.cleanBtn = frame(), frame()
dofile("ui_search.lua")
SmoeBag.UpdateHeaderLayout()
assert(SmoeBag.cleanBtn.shown and SmoeBag.searchBox.shown)
SmoeBag.frame.width = 200
SmoeBag.UpdateHeaderLayout()
assert(not SmoeBag.cleanBtn.shown and not SmoeBag.searchBox.shown)
SmoeBag.frame.width = 280
SmoeBag.UpdateHeaderLayout()
assert(not SmoeBag.cleanBtn.shown and SmoeBag.searchBox.shown)
SmoeBag.frame.width = 850
SmoeBag.UpdateHeaderLayout()
assert(SmoeBag.cleanBtn.shown and SmoeBag.searchBox.shown)

SlashCmdList = {}
dofile("main.lua")
local invoked
SmoeBag.Toggle = function() invoked = "toggle" end
SmoeBag.OpenConfig = function() invoked = "config" end
SmoeBag.CleanStart = function() invoked = "sort" end
SmoeBag.Print = function(message) invoked = message end
SlashCmdList.SMOEBAG(" CONFIG ")
assert(invoked == "config")
SlashCmdList.SMOEBAG("sort")
assert(invoked == "sort")
SlashCmdList.SMOEBAG("")
assert(invoked == "toggle")
SlashCmdList.SMOEBAG("unknown")
assert(invoked:find("Usage:", 1, true))

wipe = function(value) for key in pairs(value) do value[key] = nil end end
GetTime = function() return 100 end
ClearCursor = function() end
SmoeBag.GetSuspendUpdates = function() return false end
SmoeBag.GetNumSlots = function() return 0 end
dofile("sort.lua")
SmoeBag.CleanStart()
assert(not SmoeBag.cleanBtn.enabled)
SmoeBag.CleanOnUpdate(31)
assert(SmoeBag.cleanBtn.enabled and invoked:find("30 seconds", 1, true))

print("Parsed " .. parsed .. " modules; settings, APIs, geometry, controls and sort deadline passed.")
