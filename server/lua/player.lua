local Players = require("selene.players")
local Entities = require("selene.entities")
local Network = require("selene.network")
local HTTP = require("selene.http")
local Config = require("selene.config")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaLogin = require("server.login")
local illaLogout = require("server.logout")

Character.SeleneMethods.inform = function(user, message, messageEnglish, priority)
    local localizedMessage = user:getPlayerLanguage() == Player.english and messageEnglish or message
    Network.SendToPlayer(user.SelenePlayer, "illarion:inform", { Message = localizedMessage })
end

Character.SeleneMethods.pageGM = function(user, message)
    local webhookUrl = Config.GetProperty("notifyAdminDiscordWebhook")
    HTTP.Post(webhookUrl, { username = user.name .. " (" .. user.SelenePlayer.UserId .. ")", content = message })
end

Character.SeleneMethods.isAdmin = function(user)
    -- TODO Temporary solution until we have basic permission support in Selene
    local admins = string.split(Config.GetProperty("admins"), ",")
    return table.find(admins, user.SelenePlayer.UserId)
end

Character.SeleneMethods.getPlayerLanguage = function(user)
    if user.SelenePlayer.Language == "de" then
        return Player.german
    end
    return Player.english
end

Character.SeleneMethods.isNewPlayer = function(user)
    return user.SelenePlayer:GetCustomData(DataKeys.TotalOnlineTime, 0) < 10 * 60 * 60
end

Character.SeleneMethods.idleTime = function(user)
    return user.SelenePlayer.IdleTime
end

Character.SeleneMethods.logAdmin = function(user, message)
    local playerTypePrefix = user:isAdmin() and "Admin" or "Player"
    print("[Admin]", playerTypePrefix, user.name, "(" .. user.id .. ")", "uses admin tool:", message)
end

Players.PlayerJoined:Connect(function(player)
    local entity = Entities.Create("illarion:race_0_1")
    entity:SetCoordinate(-97, -109, 0)
    entity:AddDynamicComponent("illarion:name", function(entity, forPlayer)
        return {
            type = "visual",
            visual = "illarion:labels/character",
            properties = {
                label = entity.Name
            }
        }
    end)
    entity:SetCustomData(DataKeys.BaseAttributes .. "hitpoints", 10000)
    entity:SetCustomData(DataKeys.BaseAttributes .. "foodlevel", 10000)
    entity:SetCustomData(DataKeys.ID, 8147)
    entity:SetCustomData(DataKeys.CharacterType, Character.player)
    entity:Spawn()
    player.ControlledEntity = entity
    player.CameraEntity = entity
    player:SetCameraToFollowTarget()

    player:SetCustomData(DataKeys.CurrentLoginTimestamp, os.time())

    illaLogin.onLogin(Character.fromSelenePlayer(player))
end)

Players.PlayerLeft:Connect(function(player)
    illaLogout.onLogout(Character.fromSelenePlayer(player))
    player.ControlledEntity:Remove()

    local loginTimestamp = player:GetCustomData(DataKeys.CurrentLoginTimestamp, 0)
    local logoutTimestamp = os.time()
    local sessionOnlineTime = logoutTimestamp - loginTimestamp
    local totalOnlineTime = player:GetCustomData(DataKeys.TotalOnlineTime, 0)
    player:SetCustomData(DataKeys.TotalOnlineTime, totalOnlineTime + sessionOnlineTime)
end)
