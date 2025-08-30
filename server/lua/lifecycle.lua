local Server = require("selene.server")
local Players = require("selene.players")

local illaReload = require("server.reload")
local illaLogin = require("server.login")
local illaLogout = require("server.logout")

Players.PlayerJoined:Connect(function(player)
    local character = PlayerManager.Spawn(player)
    illaLogin.onLogin(character)
end)

Players.PlayerLeft:Connect(function(player)
    illaLogout.onLogout(Character.fromSelenePlayer(player))
    PlayerManager.Despawn(player)
end)

Server.ServerReloaded:Connect(function()
    illaReload.onReload()
end)