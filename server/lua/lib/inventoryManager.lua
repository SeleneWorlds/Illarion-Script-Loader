local IllarionInventory = require("illarion-script-loader.server.lua.lib.illarionInventory")
local Players = require("selene.players")
local Network = require("selene.network")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

local LEFT_TOOL = 5
local RIGHT_TOOL = 6
local BLOCKED_ITEM_ID = 228
local twoHandedWeaponTypes = {
    [4] = true,  -- slashingTwoHand
    [5] = true,  -- concussionTwoHand
    [6] = true,  -- punctureTwoHand
    [13] = true  -- stave
}

function m.IsBlockedHandItem(item)
    return item ~= nil and item.def:getMetadata("id") == BLOCKED_ITEM_ID
end

function m.IsTwoHandedItem(item)
    local weapon = item and item.def and item.def:getField("weapon")
    return weapon ~= nil and twoHandedWeaponTypes[tonumber(weapon.weaponType)] == true
end

-- Only weapons held in the tool slots affect the name tag; ammunition,
-- shields, and the blocked-hand placeholder keep the peaceful color.
function m.GetHeldWeaponColor(equipment)
    local melee = false
    local ranged = false
    local magic = false
    for _, slotId in ipairs({ LEFT_TOOL, RIGHT_TOOL }) do
        local item = equipment:getItem(slotId)
        local weapon = item and item.def:getField("weapon")
        local weaponType = weapon and tonumber(weapon.weaponType)
        if weaponType == 13 then
            magic = true
        elseif weaponType == 7 then
            ranged = true
        elseif weaponType and weaponType >= 1 and weaponType <= 6 then
            melee = true
        end
    end
    if magic then return 0.7, 0.8, 1 end
    if ranged then return 0, 0.8, 0.2 end
    if melee then return 1, 0.3, 0.3 end
    return 1, 1, 0.2
end

local function otherHand(slotId)
    if slotId == LEFT_TOOL then
        return RIGHT_TOOL
    elseif slotId == RIGHT_TOOL then
        return LEFT_TOOL
    end
end

-- Check the resulting hand state before an inventory move is performed. The
-- blocked item is an implementation detail and must never be moved by a user.
function m.CanMoveWithHands(fromInventory, fromSlotId, toInventory, toSlotId)
    local equipment = fromInventory.isEquipment and fromInventory
        or toInventory.isEquipment and toInventory
    if not equipment then
        return true
    end

    local fromItem = fromInventory:getItem(fromSlotId)
    local toItem = toInventory:getItem(toSlotId)
    if m.IsBlockedHandItem(fromItem) or m.IsBlockedHandItem(toItem) then
        return false
    end

    local hands = {
        [LEFT_TOOL] = equipment:getItem(LEFT_TOOL),
        [RIGHT_TOOL] = equipment:getItem(RIGHT_TOOL)
    }
    if fromInventory == equipment then
        hands[fromSlotId] = toInventory == equipment and toItem or nil
    end
    if toInventory == equipment then
        hands[toSlotId] = fromItem
    end

    for _, slotId in ipairs({ LEFT_TOOL, RIGHT_TOOL }) do
        local item = hands[slotId]
        if m.IsTwoHandedItem(item) then
            local opposite = hands[otherHand(slotId)]
            if opposite ~= nil and not m.IsBlockedHandItem(opposite) then
                return false
            end
        end
    end
    return true
end

function m.CanEquipInHand(equipment, item, slotId)
    local oppositeSlot = otherHand(slotId)
    if not oppositeSlot then
        return true
    end
    if m.IsBlockedHandItem(item) then
        return false
    end
    local current = equipment:getItem(slotId)
    if m.IsBlockedHandItem(current) then
        return false
    end
    if m.IsTwoHandedItem(item) then
        local opposite = equipment:getItem(oppositeSlot)
        return opposite == nil or m.IsBlockedHandItem(opposite)
    end
    local opposite = equipment:getItem(oppositeSlot)
    return not m.IsTwoHandedItem(opposite)
end

-- Keep the legacy placeholder in sync after a successful move. Item 228 has permanent wear.
function m.UpdateBlockedHand(equipment)
    if not equipment or not equipment.isEquipment then
        return
    end
    for _, slotId in ipairs({ LEFT_TOOL, RIGHT_TOOL }) do
        local item = equipment:getItem(slotId)
        if m.IsTwoHandedItem(item) then
            local oppositeSlot = otherHand(slotId)
            local opposite = equipment:getItem(oppositeSlot)
            if opposite == nil then
                local itemDef = require("selene.registries").findByMetadata(
                    "illarion:items", "id", BLOCKED_ITEM_ID
                )
                if itemDef then
                    equipment:setItem(oppositeSlot, {
                        def = itemDef,
                        count = 1,
                        quality = 333,
                        wear = 255,
                        data = {}
                    })
                end
            end
            return
        end
    end
    for _, slotId in ipairs({ LEFT_TOOL, RIGHT_TOOL }) do
        if m.IsBlockedHandItem(equipment:getItem(slotId)) then
            equipment:setItem(slotId, nil)
        end
    end
end

function m.InitialWear(itemDef)
    return tonumber(itemDef:getField("agingSpeed")) or 255
end

local equipmentSlotIds = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local beltSlotIds = { 12, 13, 14, 15, 16, 17 }

local equipmentBodyParts = {
    [1] = 1,   -- head
    [2] = 2,   -- neck
    [3] = 4,   -- torso
    [4] = 8,   -- hands
    [7] = 32,  -- fingers
    [8] = 32,  -- fingers
    [9] = 64,  -- legs
    [10] = 128, -- feet
    [11] = 16  -- coat
}

function m.ItemFitsEquipmentSlot(item, slotId)
    if not item or not item.def then
        return false
    end
    if slotId == 0 then
        return (tonumber(item.def:getField("containerSlots")) or 0) > 0
    end
    if slotId == 5 or slotId == 6 then
        return true
    end

    local requiredBodyPart = equipmentBodyParts[slotId]
    local armor = item.def:getField("armor")
    local bodyParts = armor and tonumber(armor.bodyParts)
    return requiredBodyPart ~= nil
        and bodyParts ~= nil
        and math.floor(bodyParts / requiredBodyPart) % 2 == 1
end

function m.SerializeItem(item)
    return item and {
        visual = item.def:getField("visual"),
        count = item.count or 1,
        container = (item.def:getField("containerSlots") or 0) > 0
    } or nil
end

local function DepotSlotIds(depotId)
    local slotIds = {}
    for i = 1, 100 do
        table.insert(slotIds, i)
    end
    return slotIds
end

function m.GetDepot(user, depotId)
    return m.GetRuntimeDataBasedInventory(user, "depot:" .. depotId, DepotSlotIds(depotId), {
        isContainer = true
    })
end

function m.CreateDetachedDepot(user, depotId)
    return IllarionInventory:new({
        data = tablex.observable(), slots = DepotSlotIds(depotId),
        owner = user, isContainer = true
    })
end

function m.GetBackpack(user)
    local item = user:getItemAt(0)
    if not item then
        return nil
    end

    return m.GetContentsContainer(item)
end

function m.GetInventoryAtView(user, viewId)
    if viewId == "belt" then
        return m.GetBelt(user)
    elseif viewId == "equipment" then
        return m.GetEquipment(user)
    elseif viewId == "backpack" then
        return m.GetBackpack(user)
    elseif type(viewId) == "string" and stringx.startsWith(viewId, "showcase:") then
        local showcaseId = tonumber(stringx.removePrefix(viewId, "showcase:"))
        local showcases = user.SeleneEntity:getRuntimeData(DataKeys.Showcases)
        local showcase = showcases and showcaseId and showcases[showcaseId]
        return showcase and showcase.inventory or nil
    elseif type(viewId) == "string" and stringx.startsWith(viewId, "depot:") then
        local depotId = tonumber(stringx.removePrefix(viewId, "depot:"))
        if depotId then
            return m.GetDepot(user, depotId)
        end
    end
    return nil
end

function m.GetShowcases(user)
    return user.SeleneEntity:getRuntimeData(DataKeys.Showcases)
end

function m.FindShowcase(user, inventory)
    for showcaseId, showcase in pairs(m.GetShowcases(user) or {}) do
        if showcase.inventory.data == inventory.data then
            return showcaseId, showcase
        end
    end
    return nil, nil
end

function m.SetShowcase(user, showcaseId, inventory, token, origin)
    m.GetShowcases(user)[showcaseId] = {
        inventory = inventory,
        token = token,
        origin = origin
    }
end

function m.CloseShowcase(user, showcaseId)
    local showcases = m.GetShowcases(user)
    local showcase = showcases[showcaseId]
    showcases[showcaseId] = nil
    return showcase
end

function m.CloseAllShowcases(user)
    local ids = {}
    for id in pairs(m.GetShowcases(user)) do ids[#ids + 1] = id end
    for _,id in ipairs(ids) do
        m.CloseShowcase(user, id)
        Network.sendToEntity(user.SeleneEntity, "illarion:close_showcase", {showcaseId = id})
    end
end

function m.CloseShowcasesForItem(user, item)
    if not item or not item.content then
        return {}
    end

    local closedShowcaseIds = {}
    for showcaseId, showcase in pairs(m.GetShowcases(user) or {}) do
        if showcase.inventory.data == item.content then
            m.CloseShowcase(user, showcaseId)
            table.insert(closedShowcaseIds, showcaseId)
        end
    end
    return closedShowcaseIds
end

function m.CloseShowcasesForWorldItem(item)
    local closedShowcases = {}
    for _, player in ipairs(Players.getOnlinePlayers()) do
        local entity = player:getControlledEntity()
        if entity then
            local user = { SeleneEntity = entity }
            for _, showcaseId in ipairs(m.CloseShowcasesForItem(user, item)) do
                table.insert(closedShowcases, { player = player, showcaseId = showcaseId })
            end
        end
    end
    return closedShowcases
end

function m.GetInventoryAtSlot(user, slotId)
    if slotId >= 0 and slotId <= 11 then
        return m.GetEquipment(user)
    elseif slotId >= 12 and slotId <= 17 then
        return m.GetBelt(user)
    end
    error("No inventory found for slotId " .. slotId)
end

function m.GetBelt(user)
    return m.GetRuntimeDataBasedInventory(user, "belt", beltSlotIds)
end

function m.GetEquipment(user)
    return m.GetRuntimeDataBasedInventory(user, "equipment", equipmentSlotIds, {
        isEquipment = true
    })
end

function m.GetRuntimeDataBasedInventory(user, inventoryName, slotIds, options)
    local inventories = user.SeleneEntity:getRuntimeData(DataKeys.Inventories)
    local inventory = inventories[inventoryName]
    if not inventory then
        inventory = IllarionInventory:new({
            data = tablex.observable(),
            slots = slotIds,
            owner = user
        })
        if options then
            for k, v in pairs(options) do
                inventory[k] = v
            end
        end
        inventories[inventoryName] = inventory
    end
    return inventory
end

function m.GetContentsContainer(item)
    local itemDef, content
    if item.SeleneItem then
        itemDef = item.SeleneItem.def
        item.SeleneItem.content = item.SeleneItem.content or tablex.observable()
        content = item.SeleneItem.content
    elseif item.SeleneEntity then
        local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item)
        if not itemData then
            return nil
        end
        local itemId = item.SeleneEntity:getEntityDefinition():getMetadata("itemId")
        itemDef = require("selene.registries").findByMetadata("illarion:items", "id", itemId)
        itemData[DataFields.Content] = itemData[DataFields.Content] or tablex.observable()
        content = itemData[DataFields.Content]
    end
    local slotCount = itemDef and itemDef:getField("containerSlots")
    if slotCount == nil or slotCount <= 0 then
        return nil
    end
    local slots = {}
    for i = 1, slotCount do
        table.insert(slots, i)
    end
    return IllarionInventory:new({
        data = content,
        slots = slots,
        isContainer = true,
        owner = item.owner
    })
end

function m.ItemMatchesFilter(itemDef, data)
    local itemId = itemDef:getMetadata("id")
    return function(item)
        if item.def:getMetadata("id") ~= itemId then
            return false
        end

        if data then
            for key, value in pairs(data) do
                if item.data[key] ~= value then
                    return false
                end
            end
        end
        return true
    end
end

return m
