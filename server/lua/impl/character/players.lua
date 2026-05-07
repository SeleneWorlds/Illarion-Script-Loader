local Network = require("selene.network")
local Config = require("selene.config")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")

Character.SeleneMethods.inform = function(user, message, messageEnglish, priority)
    if not user.SelenePlayer then
        return
    end

    local localizedMessage = user:getPlayerLanguage() == Player.english and messageEnglish or message
    Network.sendToPlayer(user.SelenePlayer, "illarion:inform", { Message = localizedMessage })
end

Character.SeleneMethods.pageGM = function(user, message)
    local webhookUrl = Config.getProperty("notifyAdminDiscordWebhook")
    HTTP.Post(webhookUrl, { username = user.name .. " (" .. user.SelenePlayer.UserId .. ")", content = message })
end

Character.SeleneMethods.isAdmin = function(user)
    if not user.SelenePlayer then
        return false
    end
    -- TODO Temporary solution until we have basic permission support in Selene
    local admins = stringx.split(Config.getProperty("admins"), ",")
    return tablex.find(admins, user.SelenePlayer.UserId) ~= nil
end

Character.SeleneMethods.getPlayerLanguage = function(user)
    if user.SelenePlayer and user.SelenePlayer:getLanguage() == "de" then
        return Player.german
    end
    return Player.english
end

Character.SeleneMethods.isNewPlayer = function(user)
    local playerData = user.SelenePlayer and user.SelenePlayer:getRuntimeData(DataKeys.Player) or nil
    return playerData and (playerData[DataFields.TotalOnlineTime] or 0) < 10 * 60 * 60 or false
end

Character.SeleneMethods.idleTime = function(user)
    return user.SelenePlayer and user.SelenePlayer:getIdleTime() or 0
end

Character.SeleneMethods.logAdmin = function(user, message)
    local playerTypePrefix = user:isAdmin() and "Admin" or "Player"
    print("[Admin]", playerTypePrefix, user.name, "(" .. user.id .. ")", "uses admin tool:", message)
end

Character.SeleneMethods.sendCharDescription = function(user, id, description)
    local target = CharacterManager.EntitiesById[id]
    if target then
        Network.sendToEntity(user.SeleneEntity, "illarion:char_description", {
            networkId = target.NetworkId,
            description = description
        })
    end
end

function Character.fromSelenePlayer(player)
    if not player:getControlledEntity() then
        print(debug.traceback())
        error("fromSelenePlayer called before the player had a controlled entity")
    end
    return setmetatable({SelenePlayer = player}, Character.SeleneMetatable)
end