local Network = require("selene.network")

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local illaDepot = require("server.depot")

Network.HandlePayload("illarion:open_container_at", function(player, payload)
    local playerEntity = player.ControlledEntity
    local dimension = playerEntity.Dimension
    local entities = dimension:GetEntitiesAt(payload.x, payload.y, payload.z, playerEntity.Collision)
    for i = #entities, 1, -1 do
        local entity = entities[i]
        if entity:HasTag("illarion:item") then
            -- TODO entity items
        end
    end
    local tiles = dimension:GetTilesAt(payload.x, payload.y, payload.z, playerEntity.Collision)
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:GetMetadata("itemId")
        if itemId then
            local isDepot = itemId == 321 or itemId == 4817
            local item = Item.fromSeleneTile(tile)
            if isDepot then
                local character = Character.fromSelenePlayer(player)
                if illaDepot.onOpenDepot(character, item) then
                    local inventory = InventoryManager.GetDepot(tonumber(item:getData("depot")))
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

Network.HandlePayload("illarion:open_container_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local inventory = nil
    if payload.viewId == "inventory" then
        inventory = InventoryManager.GetInventory(character)
    end
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