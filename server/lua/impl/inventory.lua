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

Character.SeleneMethods.createItem = function(user, itemId, count, quality, data)
    local entity = user.SeleneEntity
    local beltAttribute = entity:GetAttribute("belt")
    local beltData = beltAttribute.Value
    local slots = beltData.slots
    local slotIds = beltData:Lookup("slotIds")
    for _, slotId in ipairs(slotIds) do
        local slot = slots[slotId]
        local slotItem = slot:Lookup("item")
        if slotItem == nil then
            slot.item = {
                id = itemId,
                number = count,
                quality = quality,
                data = data
            }
            beltAttribute:Refresh(slotId)
            break
        end
    end
    return 0
end