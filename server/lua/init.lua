local illaLogin = require("illarion-vbu.server.lua.server.login")
local illaLogout = require("illarion-vbu.server.lua.server.logout")
local illaReload = require("illarion-vbu.server.lua.server.reload")

local Server = require("selene.server")
local Players = require("selene.players")
local Entities = require("selene.entities")
local Dimensions = require("selene.dimensions")

Server.ServerStarted:Connect(function()
    print("Illarion Bridge started.")
end)

Server.ServerReloaded:Connect(function()
    illaReload.onReload()
end)

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
    Player:SetControlledEntity(entity)
    Player:SetCameraEntity(entity)
    Player:SetCameraToFollowTarget()
    entity:Spawn()

    illaLogin.onLogin(Character.fromSelenePlayer(Player))
end)

Players.PlayerLeft:Connect(function(Player)
    illaLogout.onLogout(Character.fromSelenePlayer(Player))
    Player:GetControlledEntity():Remove()
end)

Entities.SteppedOnTile:Connect(function(Entity, Coordinate)
    local warpAnnotation = Entity:CollisionMap(Coordinate):GetAnnotation(Coordinate, "illarion:warp")
    if warpAnnotation then
        Entity:SetCoordinate(warpAnnotation.ToX, warpAnnotation.ToY, warpAnnotation.ToLevel)
    end
end)