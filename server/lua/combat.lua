local Network = require("selene.network")
local Schedules = require("selene.schedules")
local Entities = require("selene.entities")
local Players = require("selene.players")

Network.HandlePayload("illarion:set_combat_target", function(player, payload)
    local entity = Entities.GetEntityById(payload.networkId)
    if entity then
        SetAttackTarget(user, entity)
    end
end)

Schedules.SetInterval(100, function()
    local players = Players.GetOnlinePlayers()
    for _, player in ipairs(players) do
        if player.ControlledEntity then
            local user = Character.fromSelenePlayer(player)
            user.movepoints = user.movepoints + 1
            user.fightpoints = user.fightpoints + 1
        end
    end
end)