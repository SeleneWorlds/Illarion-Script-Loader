local Players = require("selene.players")
local Entities = require("selene.entities")
local Network = require("selene.network")
local Interface = require("illarion-api.server.lua.interface")

local illaLogin = require("server.login")
local illaLogout = require("server.logout")

Interface.Player.Inform = function(user, message)
    Network.SendToPlayer(user.SelenePlayer, "illarion:inform", { Message = message })
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