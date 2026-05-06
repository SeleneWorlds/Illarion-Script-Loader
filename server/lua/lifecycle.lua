local Server = require("selene.server")
local Players = require("selene.players")

local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")

local illaReload = require("server.reload")
local illaLogin = require("server.login")
local illaLogout = require("server.logout")

Players.playerJoined:connect(function(player)
    local character = PlayerManager.Spawn(player)
    illaLogin.onLogin(character)

    character:createItem(15, 1, 333, {})
    character:createAtPos(Character.backpack, 97, 1)
    character:createAtPos(Character.head, 184, 1)
    character:createAtPos(Character.neck, 222, 1)
    character:createAtPos(Character.breast, 4, 1)
    character:createAtPos(Character.hands, 1447, 1)
    character:createAtPos(Character.legs, 1485, 1)
    character:createAtPos(Character.feet, 1500, 1)
end)

Players.playerLeft:connect(function(player)
    if player:getControlledEntity() then
        illaLogout.onLogout(Character.fromSelenePlayer(player))
    end
    PlayerManager.Despawn(player)
end)

Server.serverReloaded:connect(function()
    illaReload.onReload()
end)