local Players = require("selene.players")
local Entities = require("selene.entities")
local Network = require("selene.network")
local Interface = require("illarion-api.server.lua.interface")

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

Players.PlayerJoined:Connect(function(Player)
    local entity = Entities.Create("illarion:human_female")
    entity:SetCoordinate(-97, -109, 0)
    entity:AddDynamicComponent("illarion:name", function(Entity, ForPlayer)
        return {
            type = "visual",
            visual = "illarion:labels/character",
            properties = {
                label = Entity.Name
            }
        }
    end)
    entity:Spawn()
    Player:SetControlledEntity(entity)
    Player:SetCameraEntity(entity)
    Player:SetCameraToFollowTarget()

    illaLogin.onLogin(Character.fromSelenePlayer(Player))
end)

Players.PlayerLeft:Connect(function(Player)
    illaLogout.onLogout(Character.fromSelenePlayer(Player))
    Player:GetControlledEntity():Remove()
end)