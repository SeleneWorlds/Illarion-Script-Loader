local Players = require("selene.players")
local Entities = require("selene.entities")
local Network = require("selene.network")
local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaLogin = require("server.login")
local illaLogout = require("server.logout")

Interface.Player.Inform = function(user, message, messageEnglish, priority)
    local localizedMessage = user:getPlayerLanguage() == Player.english and messageEnglish or message
    Network.SendToPlayer(user.SelenePlayer, "illarion:inform", { Message = localizedMessage })
end

Interface.Player.PageGM = function(user, message)
    print("PageGM", user.name, message)
end

Interface.Player.IsAdmin = function(user)
    print("IsAdmin", user.name)
    return false
end

Interface.Player.GetLanguage = function(user)
    if user.SelenePlayer.Language == "de" then
        return Player.german
    end
    return Player.english
end

Interface.Player.GetTotalOnlineTime = function(user)
    print("GetTotalOnlineTime", user.name)
    return 0
end

Interface.Player.GetID = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.ID, 0)
end

Players.PlayerJoined:Connect(function(player)
    local entity = Entities.Create("illarion:human_female")
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
    entity:SetCustomData(DataKeys.Attributes .. "hitpoints", 10000)
    entity:SetCustomData(DataKeys.Attributes .. "foodlevel", 10000)
    entity:SetCustomData(DataKeys.ID, 8147)
    entity:SetCustomData(DataKeys.CharacterType, Character.player)
    entity:Spawn()
    player.ControlledEntity = entity
    player.CameraEntity = entity
    player:SetCameraToFollowTarget()

    illaLogin.onLogin(Character.fromSelenePlayer(player))
end)

Players.PlayerLeft:Connect(function(player)
    illaLogout.onLogout(Character.fromSelenePlayer(player))
    player.ControlledEntity:Remove()
end)