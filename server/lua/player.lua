local Players = require("selene.players")
local Entities = require("selene.entities")
local Network = require("selene.network")
local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaLogin = require("server.login")
local illaLogout = require("server.logout")

Interface.Player.Inform = function(user, message)
    Network.SendToPlayer(user.SelenePlayer, "illarion:inform", { Message = message })
end

Interface.Player.PageGM = function(user, message)
    print("PageGM", user.name, message)
end

Interface.Player.IsAdmin = function(user)
    print("IsAdmin", user.name)
    return false
end

Interface.Player.GetLanguage = function(user)
    print("GetLanguage", user.name)
    return Player.german
end

Interface.Player.GetTotalOnlineTime = function(user)
    print("GetTotalOnlineTime", user.name)
    return 0
end

Interface.Player.GetID = function(user)
    print("GetID", user.name)
    return 0
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
    entity:SetCustomData(DataKeys.CharacterType, Character.player)
    entity:Spawn()
    player:SetControlledEntity(entity)
    player:SetCameraEntity(entity)
    player:SetCameraToFollowTarget()

    illaLogin.onLogin(Character.fromSelenePlayer(player))
end)

Players.PlayerLeft:Connect(function(player)
    illaLogout.onLogout(Character.fromSelenePlayer(player))
    player:GetControlledEntity():Remove()
end)