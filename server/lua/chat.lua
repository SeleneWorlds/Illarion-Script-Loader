local Network = require("selene.network")
local AdminCommands = require("illarion-script-loader.server.lua.admin_commands")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

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

    entity:updateVisuals()
end

Network.handlePayload("illarion:chat", function(player, payload)
    local message = PayloadValidation.string(payload.message, 1000)
    local modeName = PayloadValidation.oneOf(payload.mode, { normal = true, whisper = true, shout = true })
    if not message or not modeName then
        return
    end
    local character = Character.fromSelenePlayer(player)
    if message == "#i" then
        introduceToNearbyPlayers(character)
        return
    end
    if AdminCommands.handle(character, message) then
        return
    end
    local mode = Character.say
    if modeName == "whisper" then
        mode = Character.whisper
    elseif modeName == "shout" then
        mode = Character.yell
    end
    character:talk(mode, message)
end)
