local Network = require("selene.network")
local AdminCommands = require("illarion-script-loader.server.lua.admin_commands")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local function introduceToNearbyPlayers(character)
    local entity = character.SeleneEntity
    local coordinate = entity:getCoordinate()
    local nearbyEntities = entity:getDimension():getEntitiesInRange(coordinate, 2)

    for _, nearbyEntity in ipairs(nearbyEntities) do
        local nearbyCoordinate = nearbyEntity:getCoordinate()
        local characterData = nearbyEntity:getRuntimeData(DataKeys.Character)
        if nearbyCoordinate:getZ() == coordinate:getZ()
                and characterData[DataFields.CharacterType] == Character.player then
            Character.fromSeleneEntity(nearbyEntity):introduce(character)
        end
    end

    entity:updateVisual()
end

Network.handlePayload("illarion:chat", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    if payload.message == "#i" then
        introduceToNearbyPlayers(character)
        return
    end
    if AdminCommands.handle(character, payload.message) then
        return
    end
    local mode = Character.say
    if payload.mode == "whisper" then
        mode = Character.whisper
    elseif payload.mode == "yell" then
        mode = Character.yell
    end
    character:talk(mode, payload.message)
end)
