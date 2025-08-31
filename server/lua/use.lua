local Network = require("selene.network")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Network.HandlePayload("illarion:use_at", function(player, payload)
    local entity = player.ControlledEntity
    local dimension = entity.Dimension
    local entities = dimension:GetEntitiesAt(payload.x, payload.y, payload.z, entity.Collision)
    for i = #entities, 1, -1 do
        local entity = entities[i]
        local characterType = entity.CustomData[DataKeys.CharacterType]
        if characterType == Character.monster then
            local scriptName = entity.CustomData[DataKeys.Script]
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.useMonster) == "function" then
                    local illaUser = Character.fromSelenePlayer(player)
                    local illaPos = position(payload.x, payload.y, payload.z)
                    entity.CustomData[DataKeys.LastActionScript] = script
                    entity.CustomData[DataKeys.LastActionFunction] = script.useMonster
                    entity.CustomData[DataKeys.LastActionArgs] = { illaUser, illaPos }
                    script.useMonster(illaUser, illaPos)
                    return
                end
            end
        elseif characterType == Character.npc then
            local scriptName = entity.CustomData[DataKeys.Script]
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.useNPC) == "function" then
                    local illaNpc = Character.fromSeleneEntity(entity)
                    local illaUser = Character.fromSelenePlayer(player)
                    entity.CustomData[DataKeys.LastActionScript] = script
                    entity.CustomData[DataKeys.LastActionFunction] = script.useNPC
                    entity.CustomData[DataKeys.LastActionArgs] = { illaNpc, illaUser }
                    script.useNPC(illaNpc, illaUser)
                    return
                end
            end
        end
    end
    local tiles = dimension:GetTilesAt(payload.x, payload.y, payload.z, entity.Collision)
    print(payload.x, payload.y, payload.z)
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local tileScriptName = tile:GetMetadata("script")
        if tileScriptName then
            local status, script = pcall(require, tileScriptName)
            if status and type(script.useTile) == "function" then
                local illaUser = Character.fromSelenePlayer(player)
                local illaPos = position(payload.x, payload.y, payload.z)
                entity.CustomData[DataKeys.LastActionScript] = script
                entity.CustomData[DataKeys.LastActionFunction] = script.useTile
                entity.CustomData[DataKeys.LastActionArgs] = { illaUser, illaPos }
                script.useTile(illaUser, illaPos)
                return
            end
        end
        local itemId = tile:GetMetadata("itemId")
        if itemId then
            local item = Registries.FindByMetadata("illarion:items", "id", itemId)
            if item then
                local scriptName = item:GetField("script")
                if scriptName then
                    local status, script = pcall(require, scriptName)
                    if status and type(script.UseItem) == "function" then
                        local illaUser = Character.fromSelenePlayer(player)
                        local illaItem = Item.fromSeleneTile(tile)
                        entity.CustomData[DataKeys.LastActionScript] = script
                        entity.CustomData[DataKeys.LastActionFunction] = script.UseItem
                        entity.CustomData[DataKeys.LastActionArgs] = { illaUser, illaItem }
                        script.UseItem(illaUser, illaItem)
                    end
                end
            end
        end
    end
end)

Network.HandlePayload("illarion:use_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local inventory = nil
    if payload.viewId == "inventory" then
        inventory = InventoryManager.GetInventory(character)
    end

    local inventoryItem = inventory:getInventoryItem(payload.slotId)
    if inventoryItem then
        print("use", payload.viewId, payload.slotId, tablex.tostring(inventoryItem))
        local scriptName = inventoryItem.item.def:GetField("script")
        if scriptName then
            local status, script = pcall(require, scriptName)
            if status and type(script.UseItem) == "function" then
                script.UseItem(character, Item.fromSeleneInventoryItem(inventoryItem))
            end
        end
    end
end)
