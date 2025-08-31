local Dimensions = require("selene.dimensions")
local Config = require("selene.config")
local Network = require("selene.network")
local Players = require("selene.players")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")

world.SeleneMethods.getPlayerIdByName = function(world, name)
    local player = PlayerManager.getPlayerByCharacterName(name)
    if player and player.ControlledEntity then
        return true, player.ControlledEntity.CustomData[DataKeys.ID]
    end
    return false, nil
end

world.SeleneMethods.getPlayersOnline = function(world)
    local result = {}
    local players = Players.GetOnlinePlayers()
    for _, player in ipairs(players) do
        if player.ControlledEntity then
            table.insert(result, Character.fromSelenePlayer(player))
        end
    end
    return result
end

world.SeleneMethods.getPlayersInRangeOf = function(world, pos, range)
    local dimension = Dimensions.GetDefault()
    local players = Players.GetOnlinePlayers()
    local result = {}
    for _, player in ipairs(players) do
        local entity = player.ControlledEntity
        if entity and entity.Coordinate:GetHorizontalDistanceTo(pos) <= range then
            table.insert(result, Character.fromSelenePlayer(player))
        end
    end
    return result
end

world.SeleneMethods.broadcast = function(world, messageDe, messageEn)
    local players = Players.GetOnlinePlayers()
    for _, player in ipairs(players) do
        if player.Language == "de" then
            Network.SendToPlayer(player, "illarion:inform", { Message = messageDe })
        else
            Network.SendToPlayer(player, "illarion:inform", { Message = messageEn })
        end
    end
end

world.SeleneMethods.sendMonitoringMessage = function(world, message, type)
    local webhookUrl = Config.GetProperty("notifyAdminDiscordWebhook")
    HTTP.Post(webhookUrl, { content = message })
end
