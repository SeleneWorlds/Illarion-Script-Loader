local Dimensions = require("selene.dimensions")
local Config = require("selene.config")
local Network = require("selene.network")
local HTTP = require("selene.http")
local Players = require("selene.players")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")

world.SeleneMethods.getPlayerIdByName = function(world, name)
    local player = PlayerManager.getPlayerByCharacterName(name)
    local entity = player and player:getControlledEntity()
    if entity then
        local charData = entity:getRuntimeData(DataKeys.Character)
        return true, charData[DataFields.ID]
    end
    return false, nil
end

world.SeleneMethods.getPlayersOnline = function(world)
    local result = {}
    local players = Players.getOnlinePlayers()
    for _, player in ipairs(players) do
        if player:getControlledEntity() then
            table.insert(result, Character.fromSelenePlayer(player))
        end
    end
    return result
end

world.SeleneMethods.getPlayersInRangeOf = function(world, pos, range)
    local dimension = Dimensions.getDefault()
    local players = Players.getOnlinePlayers()
    local result = {}
    for _, player in ipairs(players) do
        local entity = player:getControlledEntity()
        if entity and entity:getCoordinate():getHorizontalDistanceTo(pos) <= range then
            table.insert(result, Character.fromSelenePlayer(player))
        end
    end
    return result
end

world.SeleneMethods.broadcast = function(world, messageDe, messageEn)
    local players = Players.getOnlinePlayers()
    for _, player in ipairs(players) do
        if player.Language == "de" then
            Network.sendToPlayer(player, "illarion:inform", { Message = messageDe })
        else
            Network.sendToPlayer(player, "illarion:inform", { Message = messageEn })
        end
    end
end

world.SeleneMethods.sendMonitoringMessage = function(world, message, type)
    local webhookUrl = Config.getProperty("notifyAdminDiscordWebhook")
    HTTP.post(webhookUrl, { content = message })
end
