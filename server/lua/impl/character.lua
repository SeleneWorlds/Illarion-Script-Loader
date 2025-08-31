local Network = require("selene.network")
local Registries = require("selene.registries")
local
DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")

local illaPlayerDeath = require("server.playerdeath")

local function IsDead(user)
    return user.SeleneEntity.CustomData[DataKeys.Dead]
end

Character.SeleneMethods.SeleneSetDead = function(user, dead)
    local wasDead = IsDead(user)
    user.SeleneEntity.CustomData[DataKeys.Dead] = dead
    if not wasDead and dead then
        local characterType = user.SeleneEntity.CustomData[DataKeys.CharacterType]
        if characterType == Character.player then
            user:abortAction()
            illaPlayerDeath.playerDeath(user)
        elseif characterType == Character.monster then
            local monster = user.SeleneEntity.CustomData[DataKeys.Monster]
            local scriptName = monster:GetField("script")
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.onDeath) == "function" then
                    local illaMonster = Character.fromSeleneEntity(user.SeleneEntity)
                    script.onDeath(illaMonster)
                end
            end
        end
    end
end

Character.SeleneMethods.getType = function(user)
    return user.SeleneEntity.CustomData[DataKeys.CharacterType] or Character.player
end

Character.SeleneMethods.getRace = function(user)
    local race = user.SeleneEntity.CustomData[DataKeys.Race]
    if not race then
        error("Unknown race " .. tostring(user.SeleneEntity.CustomData:RawLookup(DataKeys.Race)))
    end
    return race:GetMetadata("id")
end

Character.SeleneMethods.setRace = function(user, raceId)
    local race = Registries.FindByMetadata("illarion:races", "id", raceId)
    if race == nil then
        error("Invalid race id: " .. raceId)
    end
    local entity = user.SeleneEntity
    entity.CustomData[DataKeys.Race] = race
    local sex = user:increaseAttrib("sex", 0)
    entity:AddComponent("illarion:body", {
        type = "visual",
        visual = "illarion:race_" .. raceId .. "_" .. sex
    })
end

Character.SeleneMethods.getSkinColour = function(user)
    return AttributeManager.GetAttribute(user, "skinColor").EffectiveValue
end

Character.SeleneMethods.setSkinColour = function(user, skinColor)
    AttributeManager.GetAttribute(user, "skinColor").Value = skinColor
end

Character.SeleneMethods.getHairColour = function(user)
    return AttributeManager.GetAttribute(user, "hairColor").EffectiveValue
end

Character.SeleneMethods.setHairColour = function(user, hairColor)
    AttributeManager.GetAttribute(user, "hairColor").Value = hairColor
end

Character.SeleneMethods.getHair = function(user)
    return AttributeManager.GetAttribute(user, "hair").EffectiveValue
end

Character.SeleneMethods.setHair = function(user, hairId)
    AttributeManager.GetAttribute(user, "hair").Value = hairId
end

Character.SeleneMethods.getBeard = function(user)
    return AttributeManager.GetAttribute(user, "beard").EffectiveValue
end

Character.SeleneMethods.setBeard = function(user, beardId)
    AttributeManager.GetAttribute(user, "beard").Value = beardId
end

Character.SeleneMethods.introduce = function(user, other)
    user.SeleneEntity.CustomData[DataKeys.Introduction(other.id)] = true
    -- TODO sync name component
    error("introduce is not fully implemented - does not sync new nameplate yet")
end

Character.SeleneGetters.id = function(user)
    return user.SeleneEntity.CustomData[DataKeys.ID] or 0
end

Character.SeleneGetters.name = function(user)
    return user.SeleneEntity.Name
end

Character.SeleneGetters.pos = function(user)
    return position.FromSeleneCoordinate(user.SeleneEntity.Coordinate)
end

Character.SeleneGetters.isinvisible = function(user)
    return user.SeleneEntity:IsInvisible()
end

Character.SeleneSetters.isinvisible = function(user)
    user.SeleneEntity:MakeInvisible()
end

Character.SeleneMethods.updateAppearance = function(user)
    user.SeleneEntity:UpdateVisual()
end

Character.SeleneMethods.setClippingActive = function(user, status)
    user.SeleneEntity:SetNoClip(status)
end

Character.SeleneMethods.getClippingActive = function(user)
    return user.SeleneEntity:IsNoClip()
end

Character.SeleneMethods.getFaceTo = function(user)
   return DirectionUtils.SeleneToIlla(user.SeleneEntity.Facing) or Character.north
end

Character.SeleneMethods.warp = function(user, pos)
    -- TODO illa fails this if occupied
    user.SeleneEntity:SetCoordinate(pos)
end

Character.SeleneMethods.forceWarp = function(user, pos)
    user.SeleneEntity:SetCoordinate(pos)
end

Character.SeleneMethods.move = function(user, direction, activeMove)
    -- TODO activeMove = false means it should be a "push" (no walk animation)
    user.SeleneEntity:Move(direction)
end

Character.SeleneMethods.turn = function(user, direction)
    local seleneDirection = DirectionUtils.IllaToSelene(direction)
    if seleneDirection then
        user.SeleneEntity:SetFacing(seleneDirection)
    end
end

Character.SeleneMethods.isInRange = function(user, other, distance)
    return user:isInRangeToPosition(other.pos, distance)
end

Character.SeleneMethods.isInRangeToPosition = function(user, position, distance)
    local dx = math.abs(user.pos.x - position.x)
    local dy = math.abs(user.pos.y - position.y)
    local dz = math.abs(user.pos.z - position.z)
    return (dx <= distance) and (dy <= distance) and dz == 0
end

Character.SeleneMethods.distanceMetric = function(user, other)
    return user:distanceMetricToPosition(other.pos)
end

Character.SeleneMethods.distanceMetricToPosition = function(user, position)
    local dx = math.abs(user.pos.x - position.x)
    local dy = math.abs(user.pos.y - position.y)
    local dz = math.abs(user.pos.z - position.z)
    return math.max(dx, dy, dz)
end

Character.SeleneGetters.movepoints = function(user)
    return AttributeManager.GetAttribute(user, "actionpoints").EffectiveValue
end

Character.SeleneSetters.movepoints = function(user, value)
    AttributeManager.GetAttribute(user, "actionpoints").Value = value
end

Character.SeleneGetters.speed = function(user)
    return AttributeManager.GetAttribute(user, "speed").EffectiveValue
end

Character.SeleneSetters.speed = function(user, value)
    AttributeManager.GetAttribute(user, "speed").Value = value
end

Character.SeleneMethods.sendCharDescription = function(user, id, description)
    local target = CharacterManager.EntitiesById[id]
    if target then
        Network.SendToEntity(user.SeleneEntity, "illarion:char_description", {
            networkId = target.NetworkId,
            description = description
        })
    end
end

Character.SeleneGetters.SeleneEntity = function(user)
    return user.SelenePlayer and user.SelenePlayer.ControlledEntity or rawget(user, "SeleneEntity")
end

isValidChar = function(user)
    -- TODO This should actually check if the user is truly still valid
    return true
end

function Character.fromSelenePlayer(player)
    if not player.ControlledEntity then
        print(debug.traceback())
        error("fromSelenePlayer called before the player had a controlled entity")
    end
    return setmetatable({SelenePlayer = player}, Character.SeleneMetatable)
end

function Character.fromSeleneEntity(entity)
    local players = entity:GetControllingPlayers()
    local player = #players > 0 and players[1] or nil
    return setmetatable({SeleneEntity = entity, SelenePlayer = player}, Character.SeleneMetatable)
end