local Server = require("selene.server")
local Players = require("selene.players")
local Entities = require("selene.entities")
local Network = require("selene.network")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaReload = require("server.reload")
local illaLogin = require("server.login")
local illaLogout = require("server.logout")

Players.PlayerJoined:Connect(function(player)
    local entity = Entities.Create("illarion:race_0_1")
    entity:SetCoordinate(702, 283, 0)
    entity:AddDynamicComponent("illarion:name", function(entity, forPlayer)
        return {
            type = "visual",
            visual = "illarion:labels/character",
            properties = {
                label = entity.Name
            }
        }
    end)
    local healthAttribute = entity:GetOrCreateAttribute("hitpoints", 0)
    healthAttribute:AddObserver(function(attribute, observer)
        Network.SendToEntity(attribute.Owner, "illarion:health", { value = attribute.EffectiveValue / 10000 })
    end)
    local foodAttribute = entity:GetOrCreateAttribute("foodlevel", 0)
    foodAttribute:AddObserver(function(attribute, observer)
        Network.SendToEntity(attribute.Owner, "illarion:food", { value = attribute.EffectiveValue / 60000 })
    end)
    local manaAttribute = entity:GetOrCreateAttribute("mana", 0)
    manaAttribute:AddObserver(function(attribute, observer)
        Network.SendToEntity(attribute.Owner, "illarion:mana", { value = attribute.EffectiveValue / 10000 })
    end)
    local beltAttribute = entity:GetOrCreateAttribute("belt", tablex.managed({
        slots = tablex.managed({
            [12] = tablex.managed({}),
            [13] = tablex.managed({}),
            [14] = tablex.managed({}),
            [15] = tablex.managed({}),
            [16] = tablex.managed({}),
            [17] = tablex.managed({}),
        }),
        slotIds = {12, 13, 14, 15, 16, 17}
    }))
    beltAttribute:AddObserver(function(attribute, observerData, observableData)
        local item = attribute.Value:Lookup("slots", observableData, "item")
        Network.SendToEntity(attribute.Owner, "illarion:update_slot", { viewId = observerData, slotId = observableData, item = item })
    end, 1)
    entity:SetCustomData(DataKeys.ID, 8147)
    entity:SetCustomData(DataKeys.CharacterType, Character.player)
    entity:Spawn()
    player.ControlledEntity = entity
    player.CameraEntity = entity
    player:SetCameraToFollowTarget()

    healthAttribute.Value = 10000
    foodAttribute.Value = 60000

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