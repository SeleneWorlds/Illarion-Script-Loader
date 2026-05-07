local Inventory = require("moonlight-inventory.server.lua.inventory")
local ObservableMapInventory = require("moonlight-inventory.server.lua.observable_map_inventory")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

local equipmentSlotIds = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local beltSlotIds = { 12, 13, 14, 15, 16, 17 }
local inventorySlotIds = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

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
    if viewId == "inventory" then
        return m.GetInventory(user)
    elseif viewId == "belt" then
        return m.GetBelt(user)
    elseif viewId == "equipment" then
        return m.GetEquipment(user)
    elseif viewId == "backpack" then
        return m.GetBackpack(user)
    elseif stringx.startsWith(viewId, "depot:") then
        local depotId = tonumber(stringx.removePrefix(viewId, "depot:"))
        if depotId then
            return m.GetDepot(user, depotId)
        end
    end
    return nil
end

function m.GetInventory(user)
    return m.GetRuntimeDataBasedInventory(user, "inventory", inventorySlotIds)
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
        inventory = ObservableMapInventory:new({
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
    if item.SeleneItem then
        local itemDef = item.SeleneItem.def
        local slotCount = itemDef:getField("containerSlots")
        if slotCount == nil or slotCount <= 0 then
            return nil
        end
        item.SeleneItem.content = item.SeleneItem.content or tablex.observable()
        local slots = {}
        for i = 1, slotCount do
            table.insert(slots, i)
        end
        return ObservableMapInventory:new({
            data = item.SeleneItem.content,
            slots = slots,
            isContainer = true,
            owner = item.owner
        })
    end
    return nil
end

function m.ItemMatchesFilter(itemDef, data)
    return function(item)
        if item.def ~= itemDef then
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
