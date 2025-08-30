local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Character.SeleneMethods.getDepot = function(user, depotId)
    return Container.fromMoonlightInventory(InventoryManager.GetDepot(user, depotId))
end

Character.SeleneMethods.getBackPack = function(user, itemId)
    return Container.fromMoonlightInventory(InventoryManager.GetBackpack(user))
end

Container.SeleneMethods.countItem = function(container, itemId, data)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to count unknown item id " .. itemId)
    end
    local filter = function(item)
        return item.def == itemDef -- TODO check data too
    end
    return container.SeleneInventory:countItem(filter)
end

function Container.fromMoonlightInventory(inventeory)
    return setmetatable({SeleneInventory = inventory}, Container.SeleneMetatable)
end

Network.HandlePayload("illarion:open_container_at", function(player, payload)
    -- TODO open_container_at
end)

Network.HandlePayload("illarion:open_container_slot", function(player, payload)
    -- TODO open_container_slot
end)