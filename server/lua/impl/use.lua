local Network = require("selene.network")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Network.HandlePayload("illarion:use_at", function(player, payload)
    local entity = player.ControlledEntity
    local dimension = entity.Dimension
    local entities = dimension:GetEntitiesAt(payload.x, payload.y, payload.z, entity.Collision)
    for i = #entities, 1, -1 do
        local entity = entities[i]
        local characterType = entity.CustomData[DataKeys.CharacterType]
        if characterType == Character.monster then
            local monster = entity.CustomData[DataKeys.Monster]
            if not monster then
                error("Missing Monster data on Monster character")
            end
            local scriptName = monster:GetField("script")
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
            local npc = entity.CustomData[DataKeys.NPC]
            if not npc then
                error("Missing NPC data on NPC character")
            end
            local scriptName = npc:GetField("script")
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