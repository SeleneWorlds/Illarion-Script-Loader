local m = {}

local equipmentSlotIds = { "inventory:0", "inventory:1", "inventory:2", "inventory:3", "inventory:4", "inventory:5", "inventory:6", "inventory:7", "inventory:8", "inventory:9", "inventory:10", "inventory:11" }
local beltSlotIds = { "inventory:12", "inventory:13", "inventory:14", "inventory:15", "inventory:16", "inventory:17" }

local backpackSlots = {}
local function DepotSlotIds(depotId)
    return {}
end

function m.GetDepot(user, depotId)
    return m.GetInventory(user, "depot:" .. depotId), DepotSlotIds(depotId)
end

function m.GetBackpack(user)
    return m.GetInventory(user, "backpack", backpackSlots)
end

function m.GetBelt(user)
    return user:GetSeleneInventory("belt", beltSlotIds)
end

function m.GetEquipment(user)
    return user:GetSeleneInventory("equipment", equipmentSlotIds)
end

function m.GetInventory(user, inventoryName, slotIds)
    user.SeleneInventories = user.SeleneInventories or {}
    local inventory = user.SeleneInventories[inventoryName]
    if not inventory then
        inventory = Inventory:fromEntityAttributes(user.SeleneEntity, slotIds)
        user.SeleneInventories[inventoryName] = inventory
    end
    return inventory
end

function m.GetInventoryByPos(user, pos)
    if pos < 12 then
        return user.SeleneEquipment
    elseif pos < 18 then
        return user.SeleneBelt
    end
    return nil
end

return m