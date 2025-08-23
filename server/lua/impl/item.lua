Item.fromSeleneEntityData = function(entity, inventory, slot, data)
    return setmetatable({SeleneEntity = entity, SeleneInventory = inventory, SeleneSlot = slot, SeleneData = data}, Item.SeleneMetatable)
end

function Item.fromSeleneTile(Tile)
   return setmetatable({SeleneTile = Tile}, Item.SeleneMetatable)
end

function Item.fromSeleneEmpty()
   return setmetatable({}, Item.SeleneMetatable)
end
