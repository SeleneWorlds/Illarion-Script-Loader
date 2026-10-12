package.path = "bundles/moonlight/?.lua;bundles/?.lua;" .. package.path
local handlers = {}
package.loaded["selene.network"] = {
    handlePayload = function(name, callback) handlers[name] = callback end,
}
package.loaded["selene.registries"] = {}
package.loaded["selene.logging"] = {}
package.loaded["selene.config"] = { getProperty = function() return "false" end }
package.loaded["selene.players"] = {}
package.loaded["selene.entities"] = {}
package.loaded["illarion-script-loader.server.lua.lib.itemEntity"] = {}
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local Inventory = require("illarion-script-loader.server.lua.lib.illarionInventory")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local runtime = {}
local character = {
    pos = { x = 1, y = 2, z = 0 },
    abortAction = function() end,
    SeleneEntity = { getRuntimeData = function(_, key)
        runtime[key] = runtime[key] or {}
        return runtime[key]
    end },
}
Character = { fromSelenePlayer = function() return character end }
scriptItem = { container = 1, inventory = 2, belt = 3 }
Container = { fromSeleneInventory = function(inventory) return inventory end }
Item = { fromSeleneInventoryItem = function(item)
    return {
        id = 1, owner = item.inventory.owner, pos = character.pos,
        number = item:getItem().count, customData = {},
        getType = function() return scriptItem.belt end,
    }
end }

-- Restored inventories must receive the current character wrapper on access.
local restored = Inventory:new({ slots = { 0 }, isEquipment = true })
runtime[DataKeys.Inventories] = { equipment = restored }
assert(InventoryManager.GetEquipment(character) == restored)
assert(restored.owner == character)
restored.owner = {}
assert(InventoryManager.GetEquipment(character).owner == character)

-- Exercise the real payload handler and stack split with an ownerless container.
local source = Inventory:new({ slots = { 12 }, owner = character })
local target = Inventory:new({ slots = { 1 }, isContainer = true })
source:setItem(12, { def = { getField = function() return nil end }, count = 10 })
InventoryManager.GetInventoryAtView = function(_, view)
    return view == "belt" and source or target
end
InventoryManager.CloseShowcasesForItem = function() return {} end
require("illarion-script-loader.server.lua.transfers")
handlers["illarion:move_slot_to_slot"]({}, {
    fromViewId = "belt", fromSlotId = 12,
    toViewId = "backpack", toSlotId = 1, count = 5,
})
assert(source:getItem(12).count == 5)
assert(target:getItem(1).count == 5)
assert(target.owner == nil)
print("transfer regression tests passed")
