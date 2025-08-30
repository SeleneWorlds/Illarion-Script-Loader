local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local m = {}

m.EntitiesById = {}

function m.Spawn(player)
    local entity = Entities.Create("illarion:race_0_1")
    local id = 8147
    entity.CustomData[DataKeys.ID] = id
    entity.CustomData[DataKeys.CharacterType] = Character.player
    entity.CustomData[DataKeys.Race] = Registries.FindByName("illarion:races", "illarion:race_0")
    entity.CustomData[DataKeys.Sex] = "female"
    entity:SetCoordinate(702, 283, 0)
    entity:AddDynamicComponent("illarion:name", function(entity, forPlayer)
        local isControlled = forPlayer.ControlledEntity == entity
        local isIntroduced = forPlayer.ControlledEntity and forPlayer.ControlledEntity.CustomData[DataKeys.Introduction(entity.CustomData[DataKeys.ID])]
        local effectiveName = entity.Name
        if not isIntroduced and not isControlled then
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
    entity:Spawn()
    player.ControlledEntity = entity
    player.CameraEntity = entity
    player:SetCameraToFollowTarget()

    local character = Character.fromSelenePlayer(player)
    local beltView = entity:CreateAttributeView("belt", function(view, attributeKey, attribute)
        Network.SendToEntity(view.Owner, "illarion:update_slot", { viewId = view.Name, slotId = attributeKey, item = attribute.Value })
    end)
    InventoryManager.GetBelt(character):addToView(beltView)

    character:setAttrib("hitpoints", 10000)
    character:setAttrib("foodlevel", 30000)
    character:setMentalCapacity(10000)

    player.CustomData[DataKeys.CurrentLoginTimestamp] = os.time()

    m.EntitiesById[id] = entity
    CharacterManager.AddEntity(entity)
    return character
end

function m.Despawn(player)
    player.ControlledEntity:Remove()

    local loginTimestamp = player.CustomData[DataKeys.CurrentLoginTimestamp] or 0
    local logoutTimestamp = os.time()
    local sessionOnlineTime = logoutTimestamp - loginTimestamp
    local totalOnlineTime = player.CustomData[DataKeys.TotalOnlineTime] or 0
    player.CustomData[DataKeys.TotalOnlineTime] = totalOnlineTime + sessionOnlineTime
end

return m