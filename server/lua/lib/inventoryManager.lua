local IllarionInventory = require("illarion-script-loader.server.lua.lib.illarionInventory")
local Players = require("selene.players")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

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
        return item.def:getField("weapon") ~= nil
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
    return m.GetRuntimeDataBasedInventory(user, "equipment", equipmentSlotIds)
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
