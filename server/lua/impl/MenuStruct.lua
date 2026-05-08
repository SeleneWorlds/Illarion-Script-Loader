local Registries = require("selene.registries")

MenuStruct.SeleneConstructor = function()
    return {
        type = "MenuStruct",
        items = {}
    }
end

MenuStruct.SeleneMethods.addItem = function(self, itemId)
    table.insert(self.items, itemId)
end

