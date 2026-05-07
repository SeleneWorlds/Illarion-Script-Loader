local Network = require("selene.network")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Network.handlePayload("illarion:use_at", function(player, payload)
    local playerEntity = player:getControlledEntity()
    local dimension = playerEntity:getDimension()

    -- Entities can be either Monsters, NPCs, or non-static (dropped) items
    local entities = dimension:getEntitiesAt(payload.x, payload.y, payload.z, playerEntity:getCollisionViewer())
    for i = #entities, 1, -1 do
        local entity = entities[i]
        local charData = entity:getRuntimeData(DataKeys.Character)
        local characterType = charData[DataFields.CharacterType]
        if characterType == Character.monster then
            local scriptName = charData[DataFields.Script]
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.useMonster) == "function" then
                    local illaUser = Character.fromSelenePlayer(player)
                    local illaPos = position(payload.x, payload.y, payload.z)
                    local actionData = playerEntity:getRuntimeData(DataKeys.LastAction)
                    actionData[DataFields.LastActionScript] = script
                    actionData[DataFields.LastActionFunction] = script.useMonster
                    actionData[DataFields.LastActionArgs] = { illaUser, illaPos }
                    script.useMonster(illaUser, illaPos)
                    return
                end
            end
        elseif characterType == Character.npc then
            local scriptName = charData[DataFields.Script]
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.useNPC) == "function" then
                    local illaNpc = Character.fromSeleneEntity(entity)
                    local illaUser = Character.fromSelenePlayer(player)
                    local actionData = playerEntity:getRuntimeData(DataKeys.LastAction)
                    actionData[DataFields.LastActionScript] = script
                    actionData[DataFields.LastActionFunction] = script.useNPC
                    actionData[DataFields.LastActionArgs] = { illaNpc, illaUser }
                    script.useNPC(illaNpc, illaUser)
                    return
                end
            end
        end
    end

    -- Tiles can be either tiles or static items
    local tiles = dimension:getTilesAt(payload.x, payload.y, payload.z, playerEntity:getCollisionViewer())
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        -- If this tile has a script metadata field, we use it as a TileScript.
        local tileScriptName = tile:getMetadata("script")
        if tileScriptName then
            local status, script = pcall(require, tileScriptName)
            if status and type(script.useTile) == "function" then
                local illaUser = Character.fromSelenePlayer(player)
                local illaPos = position(payload.x, payload.y, payload.z)
                local actionData = playerEntity:getRuntimeData(DataKeys.LastAction)
                actionData[DataFields.LastActionScript] = script
                actionData[DataFields.LastActionFunction] = script.useTile
                actionData[DataFields.LastActionArgs] = { illaUser, illaPos }
                script.useTile(illaUser, illaPos)
                return
            end
        end

        -- If this tile has an itemId metadata field, we use it as an ItemScript.
        local itemId = tile:getMetadata("itemId")
        if itemId then
            local item = Registries.findByMetadata("illarion:items", "id", itemId)
            if item then
                local scriptName = item:getField("script")
                if scriptName then
                    local status, script = pcall(require, scriptName)
                    if status and type(script.UseItem) == "function" then
                        local illaUser = Character.fromSelenePlayer(player)
                        local illaItem = Item.fromSeleneTile(tile)
                        local actionData = playerEntity:getRuntimeData(DataKeys.LastAction)
                        actionData[DataFields.LastActionScript] = script
                        actionData[DataFields.LastActionFunction] = script.UseItem
                        actionData[DataFields.LastActionArgs] = { illaUser, illaItem }
                        script.UseItem(illaUser, illaItem)
                    end
                end
            end
        end
    end
end)

Network.handlePayload("illarion:use_slot", function(player, payload)
    -- Payload is viewId, slotId
    local character = Character.fromSelenePlayer(player)
    local inventory = InventoryManager.getInventoryAtView(character, payload.viewId)
    if not inventory then
        return
    end

    local inventoryItem = inventory:getInventoryItem(payload.slotId)
    if inventoryItem then
        local scriptName = inventoryItem:getItem().def:getField("script")
        if scriptName then
            local status, script = pcall(require, scriptName)
            if status and type(script.UseItem) == "function" then
                script.UseItem(character, Item.fromSeleneInventoryItem(inventoryItem))
            end
        end
    end
end)
