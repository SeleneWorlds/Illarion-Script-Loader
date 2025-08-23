local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.countItem = function(user, itemId)
    local count = 0
    local items = user.SeleneEntity:GetCustomData(DataKeys.Inventory, {})
    for _, item in pairs(items) do
        if item.id == itemId then
            count = count + item.count
        end
    end
    local backpackItem = items[Character.backpack]
    if backpackItem and backpackItem.container then
        local backpack = Container.fromSeleneEntityData(user.SeleneEntity, backpackItem.container)
        count = count + backpack:countItem()
    end
    return count
end

Character.SeleneMethods.getItemAt = function(user, slot)
    local items = user.SeleneEntity:GetCustomData(DataKeys.Inventory, {})
    local item = items[slot]
    if item then
        return Item.fromSeleneEntityData(user.SeleneEntity, items, slot, item)
    end
    return Item.fromSeleneEmpty()
end