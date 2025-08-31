local Network = require("selene.network")
local Registries = require("selene.registries")
local Players = require("selene.players")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")

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

Character.SeleneGetters.SeleneEntity = function(user)
    return user.SelenePlayer and user.SelenePlayer.ControlledEntity or rawget(user, "SeleneEntity")
end

Character.SeleneMethods.performAnimation = function(user, animId)
    user.SeleneEntity:PlayAnimation(tostring(animId))
end

Character.SeleneMethods.startMusic = function(user, id)
    Network.SendToEntity(user.SeleneEntity, "illarion:music", {
        musicId = id
    })
end

Character.SeleneMethods.defaultMusic = function()
    Network.SendToEntity(user.SeleneEntity, "illarion:music", {
        musicId = 0
    })
end

isValidChar = function(user)
    -- TODO This should actually check if the user is truly still valid
    return true
end

function Character.fromSeleneEntity(entity)
    local players = entity:GetControllingPlayers()
    local player = #players > 0 and players[1] or nil
    return setmetatable({SeleneEntity = entity, SelenePlayer = player}, Character.SeleneMetatable)
end
