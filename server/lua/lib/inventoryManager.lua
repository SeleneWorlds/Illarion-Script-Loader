local Inventory = require("moonlight-inventory.server.lua.inventory")
local ManagedTableInventory = require("moonlight-inventory.server.lua.managed_table_inventory")
local AttributeBasedInventory = require("moonlight-inventory.server.lua.attribute_based_inventory")

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
    return m.GetAttributeBasedInventory(user, "depot:" .. depotId, "illarion:depot:" .. depotId, DepotSlotIds(depotId), {
        isContainer = true
    })
end

function m.GetBackpack(user)
    local item = user:getItemAt(0)
    if not item then
        return nil
    end

    return m.GetChildContainer(item)
end

function m.GetInventory(user)
    return m.GetAttributeBasedInventory(user, "inventory", "illarion:inventory", inventorySlotIds, {
        owner = user
    })
end

function m.GetBelt(user)
    return m.GetAttributeBasedInventory(user, "belt", "illarion:inventory", beltSlotIds, {
        owner = user
    })
end

function m.GetEquipment(user)
    return m.GetAttributeBasedInventory(user, "equipment", "illarion:inventory", equipmentSlotIds, {
        owner = user
    })
end

function m.GetAttributeBasedInventory(user, inventoryName, attributeName, slotIds)
    user.SeleneInventories = user.SeleneInventories or {}
    local inventory = user.SeleneInventories[inventoryName]
    if not inventory then
        local attribute = user.SeleneEntity:GetOrCreateAttribute(attributeName, tablex.managed({}))
        inventory = AttributeBasedInventory:new(attribute, slotIds)
        user.SeleneInventories[inventoryName] = inventory
    end
    return inventory
end

function m.GetChildContainer(item)
    if item.SeleneItem then
        local itemDef = item.SeleneItem.def
        local slotCount = itemDef:GetField("containerSlots")
        if slotCount == nil then
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

function m.SetItemQuality(item, amount)
    local tmpQuality = amount + item.durability <= 99 and amount + item.quality or item.quality - item.durability + 99
    item.quality = amount
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