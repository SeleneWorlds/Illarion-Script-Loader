local Server = require("selene.server")
local Players = require("selene.players")
local Entities = require("selene.entities")
local Network = require("selene.network")
local I18n = require("selene.i18n")
local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaReload = require("server.reload")
local illaLogin = require("server.login")
local illaLogout = require("server.logout")

Players.PlayerJoined:Connect(function(player)
    local entity = Entities.Create("illarion:race_0_1")
    entity.CustomData[DataKeys.ID] = 8147
    entity.CustomData[DataKeys.CharacterType] = Character.player
    entity.CustomData[DataKeys.Race] = Registries.FindByName("illarion:races", "illarion:race_0")
    entity.CustomData[DataKeys.Sex] = "female"
    entity:SetCoordinate(702, 283, 0)
    entity:AddDynamicComponent("illarion:name", function(entity, forPlayer)
        local isIntroduced = forPlayer.ControlledEntity and forPlayer.ControlledEntity.CustomData[DataKeys.Introduction(entity.CustomData[DataKeys.ID])]
        local effectiveName = entity.Name
        if not isIntroduced then
            local race = entity.CustomData[DataKeys.Race]
            if race then
                local sex = entity.CustomData[DataKeys.Sex] or "male"
                local key = "nameTag." .. stringx.substringAfter(race.Name, "illarion:") .. "." .. sex
                effectiveName = I18n.Get(key, player.Locale) or key
            else
                effectiveName = tostring(entity.CustomData:RawLookup(DataKeys.Race))
            end
        end
        return {
            type = "visual",
            visual = "illarion:labels/character",
            properties = {
                label = effectiveName
            }
        }
    end)
    local healthAttribute = entity:GetOrCreateAttribute("hitpoints", 0)
    healthAttribute:AddObserver(function(attribute)
        Network.SendToEntity(attribute.Owner, "illarion:health", { value = attribute.EffectiveValue / 10000 })
    end)
    local foodAttribute = entity:GetOrCreateAttribute("foodlevel", 0)
    foodAttribute:AddObserver(function(attribute)
        Network.SendToEntity(attribute.Owner, "illarion:food", { value = attribute.EffectiveValue / 60000 })
    end)
    local manaAttribute = entity:GetOrCreateAttribute("mana", 0)
    manaAttribute:AddObserver(function(attribute)
        Network.SendToEntity(attribute.Owner, "illarion:mana", { value = attribute.EffectiveValue / 10000 })
    end)
    entity:Spawn()
    player.ControlledEntity = entity
    player.CameraEntity = entity
    player:SetCameraToFollowTarget()

    local character = Character.fromSelenePlayer(player)
    local beltView = entity:CreateAttributeView("belt", function(view, attributeKey, attribute)
        Network.SendToEntity(view.Owner, "illarion:update_slot", { viewId = view.Name, slotId = attributeKey, item = attribute.Value })
    end)
    character.SeleneBelt:addToView(beltView)

    healthAttribute.Value = 10000
    foodAttribute.Value = 60000

    player.CustomData[DataKeys.CurrentLoginTimestamp] = os.time()

    illaLogin.onLogin(Character.fromSelenePlayer(player))
end)

Players.PlayerLeft:Connect(function(player)
    illaLogout.onLogout(Character.fromSelenePlayer(player))
    player.ControlledEntity:Remove()

    local loginTimestamp = player.CustomData[DataKeys.CurrentLoginTimestamp] or 0
    local logoutTimestamp = os.time()
    local sessionOnlineTime = logoutTimestamp - loginTimestamp
    local totalOnlineTime = player.CustomData[DataKeys.TotalOnlineTime] or 0
    player.CustomData[DataKeys.TotalOnlineTime] = totalOnlineTime + sessionOnlineTime
end)

Server.ServerStarted:Connect(function()
    print("Illarion Bridge started.")
end)

Server.ServerReloaded:Connect(function()
    illaReload.onReload()
end)