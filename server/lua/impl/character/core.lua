local Network = require("selene.network")
local Registries = require("selene.registries")
local Players = require("selene.players")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local RouteManager = require("illarion-script-loader.server.lua.lib.routeManager")

Character.SeleneMethods.getType = function(user)
    return user.SeleneEntity:getCustomData(DataKeys.CharacterType) or Character.player
end

Character.SeleneMethods.getRace = function(user)
    local race = user.SeleneEntity:getCustomData(DataKeys.Race)
    if not race then
        error("Unknown race " .. tostring(user.SeleneEntity:getCustomData(DataKeys.Race)))
    end
    return race:getMetadata("id")
end

Character.SeleneMethods.setRace = function(user, raceId)
    local race = Registries.findByMetadata("illarion:races", "id", raceId)
    if race == nil then
        error("Invalid race id: " .. raceId)
    end
    local entity = user.SeleneEntity
    entity:setCustomData(DataKeys.Race, race)
    local sex = user:increaseAttrib("sex", 0)
    entity:addComponent("illarion:body", {
        type = "visual",
        visual = "illarion:race_" .. raceId .. "_" .. sex
    })
end

Character.SeleneMethods.introduce = function(user, other)
    user.SeleneEntity:setCustomData(DataKeys.Introduction(other.id), true)
    -- TODO sync name component
    error("introduce is not fully implemented - does not sync new nameplate yet")
end

Character.SeleneGetters.id = function(user)
    return user.SeleneEntity:getCustomData(DataKeys.ID) or 0
end

Character.SeleneGetters.name = function(user)
    return user.SeleneEntity:getName()
end

Character.SeleneGetters.pos = function(user)
    return position.FromSeleneCoordinate(user.SeleneEntity:getCoordinate())
end

Character.SeleneGetters.waypoints = function(user)
    local waypointList = rawget(user, "SeleneWaypointList")
    if waypointList == nil then
        waypointList = WaypointList.fromCharacter(user)
        rawset(user, "SeleneWaypointList", waypointList)
    end
    return waypointList
end

Character.SeleneGetters.isinvisible = function(user)
    return user.SeleneEntity:isInvisible()
end

Character.SeleneSetters.isinvisible = function(user)
    user.SeleneEntity:makeInvisible()
end

Character.SeleneMethods.updateAppearance = function(user)
    user.SeleneEntity:updateVisual()
end

Character.SeleneMethods.setClippingActive = function(user, status)
    user.SeleneEntity:setNoClip(status)
end

Character.SeleneMethods.getClippingActive = function(user)
    return user.SeleneEntity:isNoClip()
end

Character.SeleneMethods.getFaceTo = function(user)
   return DirectionUtils.SeleneToIlla(user.SeleneEntity:getFacing()) or Character.north
end

Character.SeleneMethods.warp = function(user, pos)
    -- TODO illa fails this if occupied
    user.SeleneEntity:setCoordinate(pos)
end

Character.SeleneMethods.forceWarp = function(user, pos)
    user.SeleneEntity:setCoordinate(pos)
end

Character.SeleneMethods.move = function(user, direction, activeMove)
    -- TODO activeMove = false means it should be a "push" (no walk animation)
    local seleneDirection = DirectionUtils.IllaToSelene(direction) or direction
    return user.SeleneEntity:move(seleneDirection)
end

Character.SeleneMethods.turn = function(user, direction)
    local seleneDirection = DirectionUtils.IllaToSelene(direction)
    if seleneDirection then
        user.SeleneEntity:setFacing(seleneDirection)
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

Character.SeleneMethods.getOnRoute = function(user)
    return RouteManager.GetOnRoute(user)
end

Character.SeleneMethods.setOnRoute = function(user, onRoute)
    RouteManager.SetOnRoute(user, onRoute)
end

Character.SeleneGetters.movepoints = function(user)
    return AttributeManager.GetAttribute(user, "actionpoints"):getEffectiveValue()
end

Character.SeleneSetters.movepoints = function(user, value)
    AttributeManager.GetAttribute(user, "actionpoints"):setValue(value)
end

Character.SeleneGetters.speed = function(user)
    return AttributeManager.GetAttribute(user, "speed"):getEffectiveValue()
end

Character.SeleneSetters.speed = function(user, value)
    AttributeManager.GetAttribute(user, "speed"):setValue(value)
end

Character.SeleneGetters.SeleneEntity = function(user)
    return user.SelenePlayer and user.SelenePlayer:getControlledEntity() or rawget(user, "SeleneEntity")
end

Character.SeleneMethods.performAnimation = function(user, animId)
    user.SeleneEntity:playAnimation(tostring(animId))
end

Character.SeleneMethods.startMusic = function(user, id)
    Network.sendToEntity(user.SeleneEntity, "illarion:music", {
        musicId = id
    })
end

Character.SeleneMethods.defaultMusic = function()
    Network.sendToEntity(user.SeleneEntity, "illarion:music", {
        musicId = 0
    })
end

isValidChar = function(user)
    -- TODO This should actually check if the user is truly still valid
    return true
end

function Character.fromSeleneEntity(entity)
    local players = entity:getControllingPlayers()
    local player = #players > 0 and players[1] or nil
    return setmetatable({SeleneEntity = entity, SelenePlayer = player}, Character.SeleneMetatable)
end
