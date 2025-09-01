local Inventory = require("moonlight-inventory.server.lua.inventory")
local ManagedTableInventory = require("moonlight-inventory.server.lua.managed_table_inventory")

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
    return m.GetCustomDataBasedInventory(user, "depot:" .. depotId, "illarion:depot:" .. depotId, DepotSlotIds(depotId), {
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
    end
    return nil
end

function m.GetInventory(user)
    return m.GetCustomDataBasedInventory(user, "inventory", "illarion:inventory", inventorySlotIds, {
        owner = user
    })
end

function m.GetBelt(user)
    return m.GetCustomDataBasedInventory(user, "belt", "illarion:inventory", beltSlotIds, {
        owner = user
    })
end

function m.GetEquipment(user)
    return m.GetCustomDataBasedInventory(user, "equipment", "illarion:inventory", equipmentSlotIds, {
        owner = user
    })
end

function m.GetCustomDataBasedInventory(user, inventoryName, dataKey, slotIds)
    user.SeleneInventories = user.SeleneInventories or {}
    local inventory = user.SeleneInventories[inventoryName]
    if not inventory then
        local data = user.SeleneEntity.CustomData[dataKey]
        if not data then
            data = tablex.managed()
            user.SeleneEntity.CustomData[dataKey] = data
        end
        inventory = ManagedTableInventory:new({
            data = data,
            slots = slotIds
        })
        user.SeleneInventories[inventoryName] = inventory
    end
    return inventory
end

function m.GetContentsContainer(item)
    if item.SeleneItem then
        local itemDef = item.SeleneItem.def
        local slotCount = itemDef:GetField("containerSlots")
        if slotCount == nil or slotCount <= 0 then
            return nil
        end
        local content = item.SeleneItem.content or tablex.managed()
        local slots = {}
        for i = 1, slotCount do
            table.insert(slots, i)
        end
        return ManagedTableInventory:new({
            data = content,
            slots = slots,
            isContainer = true
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