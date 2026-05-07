local Network = require("selene.network")

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local illaDepot = require("server.depot")

Network.handlePayload("illarion:open_container_at", function(player, payload)
    local playerEntity = player:getControlledEntity()
    local dimension = playerEntity:getDimension()
    local entities = dimension:getEntitiesAt(payload.x, payload.y, payload.z, playerEntity:getCollisionViewer())
    for i = #entities, 1, -1 do
        local entity = entities[i]
        if entity:hasTag("illarion:item") then
            -- TODO entity items
        end
    end
    local tiles = dimension:getTilesAt(payload.x, payload.y, payload.z, playerEntity:getCollisionViewer())
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:getMetadata("itemId")
        if itemId then
            local isDepot = itemId == 321 or itemId == 4817
            local item = Item.fromSeleneTile(tile)
            if isDepot then
                local character = Character.fromSelenePlayer(player)
                if illaDepot.onOpenDepot(character, item) then
                    local inventory = InventoryManager.getDepot(tonumber(item:getData("depot")))
                    print("opening depot " .. tablex.tostring(inventory))
                    -- TODO
                end
            else
                local inventory = InventoryManager.GetContentsContainer(item)
                -- TODO
                print("opening container " .. tablex.tostring(inventory))
            end
        end
    end
end)

Network.handlePayload("illarion:open_container_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local inventory = InventoryManager.GetInventoryAtView(character, payload.viewId)
    if not inventory then
        return
    end

    local inventoryItem = inventory:getInventoryItem(payload.slotId)
    if inventoryItem then
        local inventory = InventoryManager.GetContentsContainer(item)
        -- TODO
        print("opening item container " .. tablex.tostring(inventory))
    end
end)