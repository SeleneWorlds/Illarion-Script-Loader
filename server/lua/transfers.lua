local Network = require("selene.network")

Network.HandlePayload("illarion:move_slot_to_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local fromInventory = InventoryManager.GetInventoryAtView(character, payload.fromViewId)
    local toInventory = InventoryManager.GetInventoryAtView(character, payload.toViewId)
    if not fromInventory or not toInventory then
        return
    end

    fromInventory:moveItemTo(toInventory, payload.fromSlotId, payload.toSlotId)
end)
