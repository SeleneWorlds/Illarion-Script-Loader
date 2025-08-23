local Server = require("selene.server")
local Players = require("selene.players")
local Entities = require("selene.entities")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaReload = require("server.reload")
local illaLogin = require("server.login")
local illaLogout = require("server.logout")

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

Server.ServerStarted:Connect(function()
    print("Illarion Bridge started.")
end)

Server.ServerReloaded:Connect(function()
    illaReload.onReload()
end)