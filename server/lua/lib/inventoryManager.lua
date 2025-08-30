local Inventory = require("moonlight-inventory.server.lua.inventory")
local ManagedTableInventory = require("moonlight-inventory.server.lua.managed_table_inventory")
local AttributeBasedInventory = require("moonlight-inventory.server.lua.attribute_based_inventory")

local m = {}

local equipmentSlotIds = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local beltSlotIds = { 12, 13, 14, 15, 16, 17 }
local inventorySlotIds = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

local function DepotSlotIds(depotId)
    return {}
end

function m.GetDepot(user, depotId)
    return m.GetAttributeBasedInventory(user, "depot:" .. depotId, "illarion:depot:" .. depotId, DepotSlotIds(depotId))
end

function m.GetBackpack(user)
    -- TODO grab content from the item data in backpack slot
    return ManagedTableInventory:new()
end

function m.GetInventory(user)
    return m.GetAttributeBasedInventory(user, "inventory", "illarion:inventory", inventorySlotIds)
end

function m.GetBelt(user)
    return m.GetAttributeBasedInventory(user, "belt", "illarion:inventory", beltSlotIds)
end

function m.GetEquipment(user)
    return m.GetAttributeBasedInventory(user, "equipment", "illarion:inventory", equipmentSlotIds)
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

function m.GetInventoryByPos(user, pos)
    if pos < 12 then
        return m.GetEquipment(user)
    elseif pos < 18 then
        return m.GetBelt(user)
    end
    return nil
end

return m