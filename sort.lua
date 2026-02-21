--[[
    sort.lua
    Sort flow: (1) Stack phase – merge partial stacks via cleanQueue split ops.
    (2) BuildMoveQueue – scan bags, sort items by GetItemPriority, queue moves
    so each slot gets the correct item. (3) Defrag phase – run move queue; when
    empty, CheckIfSorted; if not, rebuild move queue and continue until done.
    GetItemInfoCached reduces API calls; button disabled while cleaning.
]]

SmoeBag = SmoeBag or {}

local TURBO_MODE = true
local PRIORITY_DEFAULT = 100

local ITEM_CLASS_CONSUMABLE = (LE_ITEM_CLASS_CONSUMABLE ~= nil) and LE_ITEM_CLASS_CONSUMABLE or 0
local ITEM_CLASS_WEAPON = (LE_ITEM_CLASS_WEAPON ~= nil) and LE_ITEM_CLASS_WEAPON or 2
local ITEM_CLASS_ARMOR = (LE_ITEM_CLASS_ARMOR ~= nil) and LE_ITEM_CLASS_ARMOR or 4
local ITEM_CLASS_REAGENT = (LE_ITEM_CLASS_REAGENT ~= nil) and LE_ITEM_CLASS_REAGENT or 5
local ITEM_CLASS_TRADEGOODS = (LE_ITEM_CLASS_TRADEGOODS ~= nil) and LE_ITEM_CLASS_TRADEGOODS or 7
local ITEM_CLASS_QUESTITEM = (LE_ITEM_CLASS_QUESTITEM ~= nil) and LE_ITEM_CLASS_QUESTITEM or 12

local CONSUMABLE_SUBCLASS_POTION = 1
local CONSUMABLE_SUBCLASS_ELIXIR = 2
local CONSUMABLE_SUBCLASS_FLASK = 3
local CONSUMABLE_SUBCLASS_FOOD_DRINK = 5
local GetItemInfoCached

-- Priority: lower = earlier in bags. Order: hearthstone, potions, elixirs,
-- flasks, food, pet food, trade goods, gear, quest, other.
local function GetItemPriority(id, itemType, subType, name, classID, subclassID)
    name = name or ""
    subType = subType or ""
    local lowerName = name:lower()
    local typeLower = (itemType or ""):lower()
    local subLower  = subType:lower()

    -- 1) Hearthstone first, always.
    if id == 6948 then
        return 0
    end

    -- Numeric class IDs are locale-independent and stable across clients.
    if classID == ITEM_CLASS_CONSUMABLE then
        if subclassID == CONSUMABLE_SUBCLASS_POTION then
            return 10
        end
        if subclassID == CONSUMABLE_SUBCLASS_ELIXIR then
            return 11
        end
        if subclassID == CONSUMABLE_SUBCLASS_FLASK then
            return 12
        end
        if subclassID == CONSUMABLE_SUBCLASS_FOOD_DRINK then
            return 13
        end
    elseif classID == ITEM_CLASS_TRADEGOODS or classID == ITEM_CLASS_REAGENT then
        return 30
    elseif classID == ITEM_CLASS_ARMOR or classID == ITEM_CLASS_WEAPON then
        return 40
    elseif classID == ITEM_CLASS_QUESTITEM then
        return 60
    end

    -- Locale‑tolerant helpers (en + de keywords)
    local function isConsumable()
        return typeLower:find("consum") or typeLower:find("verbrau")
    end

    local function isTradeGoods()
        return typeLower:find("trade") or typeLower:find("handwerks") or typeLower:find("waren")
    end

    local function isReagent()
        return typeLower:find("reagent") or typeLower:find("reagenz")
    end

    local function isArmor()
        return typeLower:find("armor") or typeLower:find("rüstung")
    end

    local function isWeapon()
        return typeLower:find("weapon") or typeLower:find("waffe")
    end

    local function isQuest()
        return typeLower:find("quest")
    end

    -- 2) Combat/utility consumables near the top, clustered by type.
    if isConsumable() then
        -- Potions
        if subLower:find("potion") or lowerName:find("potion") or lowerName:find("trank") then
            return 10
        end

        -- Elixirs
        if subLower:find("elixir") or lowerName:find("elixir") or lowerName:find("elixier") then
            return 11
        end

        -- Flasks
        if subLower:find("flask") or lowerName:find("flask") then
            return 12
        end

        -- Food & drink for the player
        if subLower:find("food") or subLower:find("drink") or
           lowerName:find("food") or lowerName:find("drink") or
           lowerName:find("speise") or lowerName:find("wasser") then
            return 13
        end

        -- 3) Raw pet food just after normal food/drink.
        if lowerName:find("meat") or lowerName:find("fleisch") or
           lowerName:find("fish") or lowerName:find("fisch") or
           lowerName:find("cheese") or lowerName:find("käse") or
           lowerName:find("bread") or lowerName:find("brot") or
           lowerName:find("fruit") or lowerName:find("frucht") or
           lowerName:find("fungus") or lowerName:find("pilz") then
            return 15
        end

        -- Other consumables a bit further down, but still above most.
        return 20
    end

    -- 4) Trade goods / reagents.
    if isTradeGoods() or isReagent() then
        return 30
    end

    -- 5) Gear (armor/weapons) after trade goods.
    if isArmor() or isWeapon() then
        return 40
    end

    -- 6) Quest items after gear (you already get a special glow).
    if isQuest() then
        return 60
    end

    -- 7) Everything else at the back.
    return PRIORITY_DEFAULT
end

local function GetPriorityFromLink(link, id)
    if not link then
        return PRIORITY_DEFAULT
    end

    local info = GetItemInfoCached(link)
    local name, itemType, subType, classID, subclassID
    if info then
        name = info.name
        itemType = info.class
        subType = info.subclass
        classID = info.classID
        subclassID = info.subclassID
    end

    if not name then
        local n, _, _, _, _, it, st, _, _, _, _, cID, scID = GetItemInfo(link)
        name = n or name
        itemType = it or itemType
        subType = st or subType
        classID = cID or classID
        subclassID = scID or subclassID
    end

    if (classID == nil or subclassID == nil) and GetItemInfoInstant then
        local iid, _, _, _, _, cID, scID = GetItemInfoInstant(link)
        id = id or iid
        classID = classID or cID
        subclassID = subclassID or scID
    end

    return GetItemPriority(id, itemType, subType, name, classID, subclassID)
end

local CLEAN_THROTTLE = TURBO_MODE and 0.1 or 0.25

local CLEAN_STEP_DT = TURBO_MODE and 0.005 or 0.01
local CLEAN_MAX_OPS_PER_TICK = TURBO_MODE and 5 or 3

local CLEAN_MAX_FAILS_PER_JOB = 50
local CLEAN_W = 52
local CLEAN_H = 22

local lastClean = 0
local cleaning = false
local cleanQueue = {}
local cleanStepTimer = 0
local cleanPhase = "idle"  -- "stack" | "defrag" | "idle"
local emptySlots = {}
local fullSlots = {}
local itemInfoCache = {}

function SmoeBag.CursorHasSomething()
    return (CursorHasItem and CursorHasItem()) or (GetCursorInfo and GetCursorInfo() ~= nil)
end

function SmoeBag.CursorClearSafe()
    if ClearCursor then ClearCursor() end
end

function SmoeBag.IsLocked(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.isLocked
    end
    if GetContainerItemInfo then
        local _, _, locked = GetContainerItemInfo(bag, slot)
        return locked
    end
    return false
end

-- --- Helpers ---
local function Enqueue(op)
    op.fail = 0
    cleanQueue[#cleanQueue + 1] = op
end

GetItemInfoCached = function(link)
    if not link then return nil end
    local id = SmoeBag.ItemIDFromLink(link)
    if not id then return nil end
    
    -- Check cache first
    if itemInfoCache[id] then
        return itemInfoCache[id]
    end
    
    -- Call API and cache result (even if nil)
    local name, link2, quality, itemLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = GetItemInfo(link)
    
    local info = nil
    if name then -- Only cache if we got valid data
        info = {
            name = name,
            link = link2,
            quality = quality,
            itemLevel = itemLevel,
            reqLevel = reqLevel,
            class = class,
            subclass = subclass,
            maxStack = maxStack,
            equipSlot = equipSlot,
            texture = texture,
            sellPrice = sellPrice,
            classID = classID,
            subclassID = subclassID,
            bindType = bindType,
            expacID = expacID,
            setID = setID,
            isCraftingReagent = isCraftingReagent
        }
    end
    
    itemInfoCache[id] = info
    return info
end

local function UpdateSortButtonState()
    if not SmoeBag.cleanBtn then return end
    if cleaning then
        SmoeBag.cleanBtn:SetEnabled(false)
        SmoeBag.cleanBtn:SetText("Sorting...")
    else
        SmoeBag.cleanBtn:SetEnabled(true)
        SmoeBag.cleanBtn:SetText("Sort")
    end
end

local function DoMove(srcBag, srcSlot, dstBag, dstSlot)
    if SmoeBag.CursorHasSomething() then return false end
    if SmoeBag.IsLocked(srcBag, srcSlot) then return false end
    SmoeBag.PickupSlot(srcBag, srcSlot)
    if not SmoeBag.CursorHasSomething() then 
        SmoeBag.CursorClearSafe() 
        return false 
    end
    SmoeBag.PickupSlot(dstBag, dstSlot)
    if SmoeBag.CursorHasSomething() then 
        SmoeBag.PickupSlot(srcBag, srcSlot) 
        SmoeBag.CursorClearSafe() 
        return false 
    end
    return true
end

local function DoSplit(srcBag, srcSlot, amount, dstBag, dstSlot)
    if amount <= 0 then return true end
    if SmoeBag.CursorHasSomething() then return false end
    if SmoeBag.IsLocked(srcBag, srcSlot) then return false end
    if not SplitContainerItem then return false end
    SplitContainerItem(srcBag, srcSlot, amount)
    if not SmoeBag.CursorHasSomething() then 
        SmoeBag.CursorClearSafe() 
        return false 
    end
    SmoeBag.PickupSlot(dstBag, dstSlot)
    if SmoeBag.CursorHasSomething() then 
        SmoeBag.CursorClearSafe() 
        return false 
    end
    return true
end

-- --- Defrag: check if bags match target order ---
local function CheckIfSorted()
    -- Check if all items are in their correct hierarchical positions
    local max = NUM_BAG_SLOTS or 4
    local allItems = {}
    local idx = 0

    -- Scan all current positions
    for bag = 0, max do
        if SmoeBag.GetBagFamilySafe(bag) == 0 then
            local n = SmoeBag.GetNumSlots(bag)
            for slot = 1, n do
                idx = idx + 1
                local link = SmoeBag.GetItemLinkSafe(bag, slot)
                if link then
                    local id = SmoeBag.ItemIDFromLink(link)
                    local prio = GetPriorityFromLink(link, id)
                    table.insert(allItems, {
                        bag = bag,
                        slot = slot,
                        idx = idx,
                        prio = prio,
                        link = link,
                        id = id
                    })
                else
                    -- Empty slot
                    table.insert(allItems, {
                        bag = bag,
                        slot = slot,
                        idx = idx,
                        prio = PRIORITY_DEFAULT + 1000,
                        link = nil,
                        id = nil
                    })
                end
            end
        end
    end

    -- Sort by priority to get target order
    table.sort(allItems, function(a, b)
        if a.prio ~= b.prio then
            return a.prio < b.prio
        end
        if (a.link and not b.link) then return true end
        if (b.link and not a.link) then return false end
        if a.id and b.id and a.id ~= b.id then
            return a.id < b.id
        end
        return a.idx < b.idx
    end)

    -- Check if current positions match target order
    idx = 0
    for bag = 0, max do
        if SmoeBag.GetBagFamilySafe(bag) == 0 then
            local n = SmoeBag.GetNumSlots(bag)
            for slot = 1, n do
                idx = idx + 1
                local targetItem = allItems[idx]
                if targetItem and targetItem.link then
                    local currentLink = SmoeBag.GetItemLinkSafe(bag, slot)
                    local currentId = currentLink and SmoeBag.ItemIDFromLink(currentLink) or nil
                    if currentId ~= targetItem.id then
                        return false -- Found a mismatch
                    end
                end
            end
        end
    end
    return true -- Everything is sorted correctly
end

-- --- Defrag: build move queue from current positions + priority order ---
local function BuildMoveQueue()
    -- Build move queue based on CURRENT item positions (after stacking)
    local max = NUM_BAG_SLOTS or 4
    local allItems = {}
    local idx = 0

    -- Scan all current positions
    for bag = 0, max do
        if SmoeBag.GetBagFamilySafe(bag) == 0 then
            local n = SmoeBag.GetNumSlots(bag)
            for slot = 1, n do
                idx = idx + 1
                local link = SmoeBag.GetItemLinkSafe(bag, slot)
                if link then
                    local id = SmoeBag.ItemIDFromLink(link)
                    local prio = GetPriorityFromLink(link, id)
                    table.insert(allItems, {
                        bag = bag,
                        slot = slot,
                        idx = idx,
                        prio = prio,
                        link = link,
                        id = id
                    })
                else
                    -- Empty slot
                    table.insert(allItems, {
                        bag = bag,
                        slot = slot,
                        idx = idx,
                        prio = PRIORITY_DEFAULT + 1000,
                        link = nil,
                        id = nil
                    })
                end
            end
        end
    end

    -- Sort by priority to get target order
    table.sort(allItems, function(a, b)
        if a.prio ~= b.prio then
            return a.prio < b.prio
        end
        if (a.link and not b.link) then return true end
        if (b.link and not a.link) then return false end
        if a.id and b.id and a.id ~= b.id then
            return a.id < b.id
        end
        return a.idx < b.idx
    end)

    -- Build target positions
    local targetOrder = {}
    idx = 0
    for bag = 0, max do
        if SmoeBag.GetBagFamilySafe(bag) == 0 then
            local n = SmoeBag.GetNumSlots(bag)
            for slot = 1, n do
                idx = idx + 1
                table.insert(targetOrder, {
                    bag = bag,
                    slot = slot,
                    idx = idx,
                    targetItem = allItems[idx]
                })
            end
        end
    end

    -- Queue moves for items not in correct position
    for _, target in ipairs(targetOrder) do
        if target.targetItem and target.targetItem.link then
            local targetBag = target.targetItem.bag
            local targetSlot = target.targetItem.slot
            local destBag = target.bag
            local destSlot = target.slot

            if targetBag ~= destBag or targetSlot ~= destSlot then
                Enqueue({
                    op = "move",
                    sb = targetBag,
                    ss = targetSlot,
                    db = destBag,
                    ds = destSlot,
                    expectedId = target.targetItem.id
                })
            end
        end
    end
end

-- --- Stack phase: build split ops for stacking ---
local function BuildStackQueueOnly()
    wipe(cleanQueue)
    wipe(emptySlots)
    wipe(fullSlots)
    local max = NUM_BAG_SLOTS or 4
    local slotsOrdered = {}

    for bag = 0, max do
        local fam = SmoeBag.GetBagFamilySafe(bag)
        if fam == 0 then
            local n = SmoeBag.GetNumSlots(bag)
            for slot = 1, n do
                local it = SmoeBag.GetItemInfoSafe(bag, slot)
                local link = (it and it.hyperlink) or SmoeBag.GetItemLinkSafe(bag, slot)
                local count = (it and it.stackCount) or (link and 1) or 0
                local id = link and SmoeBag.ItemIDFromLink(link) or nil
                local maxStack = 1
                local prio = link and GetPriorityFromLink(link, id) or PRIORITY_DEFAULT
                if link then
                    local info = GetItemInfoCached(link)
                    if info then
                        maxStack = info.maxStack or 1
                    else
                        -- GetItemInfo failed or not cached yet - use defaults
                        -- Try direct call as fallback (might work on second pass)
                        local name, _, _, _, _, _, _, ms = GetItemInfo(link)
                        if name then
                            maxStack = ms or 1
                        end
                    end
                end
                slotsOrdered[#slotsOrdered + 1] = {
                    bag = bag,
                    slot = slot,
                    link = link,
                    id = id,
                    count = count,
                    maxStack = maxStack,
                    prio = prio,
                }
            end
        end
    end

    local byId = {}
    for i, e in ipairs(slotsOrdered) do
        if e.id and e.maxStack and e.maxStack > 1 and e.count and e.count > 0 then
            byId[e.id] = byId[e.id] or {}
            byId[e.id][#byId[e.id] + 1] = i
        end
    end

    for id, idxs in pairs(byId) do
        if #idxs >= 2 then
            local receivers, donors = {}, {}
            for _, i in ipairs(idxs) do
                local e = slotsOrdered[i]
                if e.count < e.maxStack then receivers[#receivers + 1] = i end
                if e.count > 0 then donors[#donors + 1] = i end
            end

            table.sort(receivers, function(a, b) return slotsOrdered[a].count < slotsOrdered[b].count end)
            table.sort(donors, function(a, b) return slotsOrdered[a].count > slotsOrdered[b].count end)

            for _, ri in ipairs(receivers) do
                local r = slotsOrdered[ri]
                local need = r.maxStack - r.count
                if need > 0 then
                    for _, di in ipairs(donors) do
                        if need <= 0 then break end
                        if di ~= ri then
                            local d = slotsOrdered[di]
                            if d.count and d.count > 0 then
                                local take = math.min(need, d.count)
                                if take > 0 then
                                    Enqueue({ op = "split", sb = d.bag, ss = d.slot, amt = take, db = r.bag, ds = r.slot })
                                    d.count = d.count - take
                                    r.count = r.count + take
                                    need = need - take
                                    if d.count == 0 then d.link = nil; d.id = nil; d.maxStack = 1 end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Build complete list of all items with their current positions
    local allItems = {}
    local idx = 0
    for bag = 0, max do
        if SmoeBag.GetBagFamilySafe(bag) == 0 then
            local n = SmoeBag.GetNumSlots(bag)
            for slot = 1, n do
                idx = idx + 1
                local link = SmoeBag.GetItemLinkSafe(bag, slot)
                if link then
                    local id = SmoeBag.ItemIDFromLink(link)
                    local prio = GetPriorityFromLink(link, id)
                    table.insert(allItems, {
                        bag = bag,
                        slot = slot,
                        idx = idx,
                        prio = prio,
                        link = link,
                        id = id
                    })
                else
                    -- Empty slot - will be filled by items later in hierarchy
                    table.insert(allItems, {
                        bag = bag,
                        slot = slot,
                        idx = idx,
                        prio = PRIORITY_DEFAULT + 1000, -- Very low priority, goes to end
                        link = nil,
                        id = nil
                    })
                end
            end
        end
    end

    -- Sort all items by priority to get target order
    -- Within same priority, sort by name/ID for stability
    table.sort(allItems, function(a, b)
        if a.prio ~= b.prio then
            return a.prio < b.prio
        end
        -- Same priority: prefer non-empty, then by ID/name
        if (a.link and not b.link) then return true end
        if (b.link and not a.link) then return false end
        if a.id and b.id and a.id ~= b.id then
            return a.id < b.id
        end
        return a.idx < b.idx -- Original position as tiebreaker
    end)

    -- Now build target positions: what should be in each slot (left to right, top to bottom)
    local targetOrder = {}
    idx = 0
    for bag = 0, max do
        if SmoeBag.GetBagFamilySafe(bag) == 0 then
            local n = SmoeBag.GetNumSlots(bag)
            for slot = 1, n do
                idx = idx + 1
                table.insert(targetOrder, {
                    bag = bag,
                    slot = slot,
                    idx = idx,
                    targetItem = allItems[idx] -- What SHOULD be here
                })
            end
        end
    end

    -- Stacking queue is built above, move queue will be built after stacking completes
    -- Keep old emptySlots/fullSlots for backward compatibility (not used anymore)
    wipe(emptySlots)
    wipe(fullSlots)
end

function SmoeBag.CleanStart()
    if InCombatLockdown and InCombatLockdown() then 
        SmoeBag.Print("Can't sort in combat.") 
        return 
    end
    local t = GetTime and GetTime() or 0
    if t - lastClean < CLEAN_THROTTLE then return end
    lastClean = t
    if cleaning then 
        SmoeBag.Print("Sort already running.") 
        return 
    end

    -- Clear cache at start of new sort pass
    wipe(itemInfoCache)
    
    SmoeBag.CursorClearSafe()
    BuildStackQueueOnly()

    cleaning = true
    cleanStepTimer = 0
    -- After stacking, we move to defrag which processes the move queue
    cleanPhase = (#cleanQueue > 0) and "stack" or "defrag"
    
    -- Update button state
    UpdateSortButtonState()
end

function SmoeBag.CleanOnUpdate(dt)
    if not cleaning then return end
    if SmoeBag.GetSuspendUpdates() then return end
    if InCombatLockdown and InCombatLockdown() then
        cleaning = false
        cleanPhase = "idle"
        wipe(cleanQueue)
        wipe(itemInfoCache)
        SmoeBag.CursorClearSafe()
        UpdateSortButtonState()
        SmoeBag.Print("Sort paused in combat.")
        return
    end
    if SmoeBag.CursorHasSomething() then 
        SmoeBag.CursorClearSafe() 
        return 
    end

    cleanStepTimer = cleanStepTimer + dt
    if cleanStepTimer < CLEAN_STEP_DT then return end
    cleanStepTimer = 0

    local ops = 0
    while ops < CLEAN_MAX_OPS_PER_TICK do
        ops = ops + 1

        if cleanPhase == "stack" then
            local job = cleanQueue[1]
            if not job then 
                -- Stacking done, rebuild move queue with current positions
                BuildMoveQueue()
                cleanPhase = "defrag" 
                if SmoeBag.MarkDirtyAll then 
                    SmoeBag.MarkDirtyAll() 
                end 
                break
            end
            local ok = false
            if job.op == "split" then 
                ok = DoSplit(job.sb, job.ss, job.amt, job.db, job.ds) 
            end
            if ok then 
                table.remove(cleanQueue, 1) 
                if SmoeBag.MarkDirtyAll then 
                    SmoeBag.MarkDirtyAll() 
                end 
            else
                job.fail = (job.fail or 0) + 1
                if job.fail >= CLEAN_MAX_FAILS_PER_JOB then 
                    table.remove(cleanQueue, 1) 
                    SmoeBag.CursorClearSafe() 
                    if SmoeBag.MarkDirtyAll then 
                        SmoeBag.MarkDirtyAll() 
                    end 
                end
            end
            -- Continue to next iteration

        elseif cleanPhase == "defrag" then
            -- Process move queue: place items in their correct positions one by one
            local job = cleanQueue[1]
            if not job then 
                -- Move queue empty, check if everything is sorted correctly
                if CheckIfSorted() then
                    -- Everything is sorted! We're done.
                    cleaning = false 
                    cleanPhase = "idle"
                    wipe(itemInfoCache) -- Clear cache when done
                    UpdateSortButtonState()
                    if SmoeBag.MarkDirtyAll then 
                        SmoeBag.MarkDirtyAll() 
                    end 
                    break
                else
                    -- Not fully sorted yet, rebuild move queue and continue
                    BuildMoveQueue()
                    if #cleanQueue == 0 then
                        -- No moves needed (shouldn't happen if CheckIfSorted returned false, but be safe)
                        cleaning = false 
                        cleanPhase = "idle"
                        wipe(itemInfoCache) -- Clear cache when done
                        UpdateSortButtonState()
                        if SmoeBag.MarkDirtyAll then 
                            SmoeBag.MarkDirtyAll() 
                        end 
                        break
                    end
                    -- Continue processing the new move queue.
                    -- Re-fetch first job after rebuilding, otherwise `job` stays nil.
                    job = cleanQueue[1]
                    if not job then
                        break
                    end
                end
            end

            if job.op == "move" then
                -- Verify the source still has the expected item
                local sourceLink = SmoeBag.GetItemLinkSafe(job.sb, job.ss)
                local sourceId = sourceLink and SmoeBag.ItemIDFromLink(sourceLink) or nil
                local expectedId = job.expectedId
                
                -- Check if destination already has the right item
                local destLink = SmoeBag.GetItemLinkSafe(job.db, job.ds)
                local destId = destLink and SmoeBag.ItemIDFromLink(destLink) or nil
                
                if expectedId and destId == expectedId then
                    -- Already in place, skip this move
                    table.remove(cleanQueue, 1)
                    if SmoeBag.MarkDirtyAll then 
                        SmoeBag.MarkDirtyAll() 
                    end
                elseif expectedId and sourceId == expectedId then
                    -- Source has the expected item, safe to move
                    local ok = DoMove(job.sb, job.ss, job.db, job.ds)
                    if ok then
                        table.remove(cleanQueue, 1)
                        if SmoeBag.MarkDirtyAll then 
                            SmoeBag.MarkDirtyAll() 
                        end
                    else
                        job.fail = (job.fail or 0) + 1
                        if job.fail >= CLEAN_MAX_FAILS_PER_JOB then
                            table.remove(cleanQueue, 1)
                            SmoeBag.CursorClearSafe()
                            if SmoeBag.MarkDirtyAll then 
                                SmoeBag.MarkDirtyAll() 
                            end
                        end
                    end
                else
                    -- Source doesn't have expected item (was moved already), skip this move
                    table.remove(cleanQueue, 1)
                    if SmoeBag.MarkDirtyAll then 
                        SmoeBag.MarkDirtyAll() 
                    end
                end
            else
                -- Unknown op type, remove it
                table.remove(cleanQueue, 1)
            end
        else
            -- Unknown phase, bail out defensively.
            break
        end
    end
end

-- --- Sort button (disabled + "Sorting..." while cleaning) ---
local cleanBtn = CreateFrame("Button", nil, SmoeBag.frame, "UIPanelButtonTemplate")
cleanBtn:SetSize(CLEAN_W, CLEAN_H)
cleanBtn:SetText("Sort")
cleanBtn:SetPoint("TOPRIGHT", SmoeBag.searchBox, "TOPLEFT", -6, 0)  -- HEADER_BTN_GAP from ui_search
cleanBtn:SetFrameLevel(SmoeBag.frame:GetFrameLevel() + 10)
cleanBtn:SetScript("OnClick", SmoeBag.CleanStart)
SmoeBag.cleanBtn = cleanBtn

-- Export constants for other modules
SmoeBag.CLEAN_W = CLEAN_W
SmoeBag.CLEAN_H = CLEAN_H

-- Initialize button state
UpdateSortButtonState()
