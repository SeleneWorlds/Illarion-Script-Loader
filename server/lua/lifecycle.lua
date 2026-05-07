local Server = require("selene.server")
local Players = require("selene.players")

local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")

local ok, illaReload = pcall(require, "server.reload")
local ok, illaReloadDefs = pcall(require, "server.reload_defs")
local ok, illaReloadTables = pcall(require, "server.reload_tables")
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
    if illaReload then
        illaReload.onReload()
    end
    if illaReloadDefs then
        illaReloadDefs.onReload()
    end
    if illaReloadTables then
        illaReloadTables.onReload()
    end
end)