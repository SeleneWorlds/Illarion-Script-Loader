local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getDepot = function(user, depotId)
    local depotData = user.SeleneEntity.CustomData[DataKeys.Depot .. depotId] or {}
    return Container.fromSeleneEntityData(user.SeleneEntity, depotData)
end

Container.SeleneMethods.countItem = function(container, itemId, data)
    local count = 0
    local items = container.SeleneData.Items or {}
    for _, item in pairs(items) do
        if item.id == itemId then
            -- TODO check against data too
            count = count + item.count
        end

        if item.container then
            local childContainer = Container.fromSeleneEntityData(container.SeleneEntity, item.container)
            count = count + childContainer:countItem(itemId, data)
        end
    end
    return count
end

function Container.fromMoonlightInventory(inventeory)
    return setmetatable({SeleneInventory = inventory}, Container.SeleneMetatable)
end

function Container.fromSeleneEntityData(entity, data)
    return setmetatable({SeleneEntity = entity, SeleneData = data}, Container.SeleneMetatable)
end