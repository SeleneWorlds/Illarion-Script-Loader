local Interface = require("illarion-api.server.lua.interface")

--[[m.Inventory = {
    ChangeQualityAt = function(user, bodyPosition, amount) end,
    CountItem = function(user, itemId) return 0 end,
    CountItemAt = function(user, slots, itemId, data) return 0 end,
    EraseItem = function(user, itemId, count, data) end,
    IncreaseAtPos = function(user, bodyPosition, count) end,
    SwapAtPos = function(user, bodyPosition, itemId, quality) end,
    CreateItem = function(user, itemId, count, quality, data) return 0 end,
    CreateAtPos = function(user, bodyPosition, itemId, count) end,
    GetItemAt = function(user, bodyPosition) return Item.fromSeleneEmpty() end,
    GetItem = function(user, itemId, data) return Item.fromSeleneEmpty() end,
    GetBackpack = function(user) return SeleneContainer() end,
    GetDepot = function(user, depotId) return SeleneContainer() end
}]]