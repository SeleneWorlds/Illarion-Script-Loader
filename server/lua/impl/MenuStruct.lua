local Registries = require("selene.registries")

MenuStruct.SeleneConstructor = function(title, callback)
    return {
        type = "MenuStruct",
        title = title,
        callback = callback,
        items = {}
    }
end

MenuStruct.SeleneMethods.addItem = function(self, itemId)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Unknown item id " .. itemId)
    end

    table.insert(self.items, {
        id = itemId,
        visual = itemDef:getField("visual")
    })
end
