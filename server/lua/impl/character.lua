local Network = require("selene.network")
local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getType = function(user)
    return user.SeleneEntity:GetCustomData(DataKeys.CharacterType, Character.player)
end

Character.SeleneMethods.getRace = function(user)
    return user.SeleneEntity:GetCustomData(DataKeys.Race, 0)
end

Character.SeleneMethods.setRace = function(user, raceId)
    local entity = user.SeleneEntity
    entity:SetCustomData(DataKeys.Race, raceId)
    local sex = user:increaseAttrib("sex", 0)
    entity:AddComponent("illarion:body", {
        type = "visual",
        visual = "illarion:race_" .. raceId .. "_" .. sex
    })
end

Character.SeleneMethods.getSkinColour = function(user)
    return user.SeleneEntity:GetCustomData(DataKeys.SkinColor, colour(255, 255, 255))
end

Character.SeleneMethods.setSkinColour = function(user, skinColor)
    user.SeleneEntity:SetCustomData(DataKeys.SkinColor, skinColor)
end

Character.SeleneMethods.getHairColour = function(user)
    return user.SeleneEntity:GetCustomData(DataKeys.HairColor, colour(255, 255, 255))
end

Character.SeleneMethods.setHairColour = function(user, hairColor)
    user.SeleneEntity:SetCustomData(DataKeys.HairColor, hairColor)
end

Character.SeleneMethods.getHair = function(user)
    return user.SeleneEntity:GetCustomData(DataKeys.Hair, 0)
end

Character.SeleneMethods.setHair = function(user, hairId)
    user.SeleneEntity:SetCustomData(DataKeys.Hair, hairId)
end

Character.SeleneMethods.getBeard = function(user)
    return user.SeleneEntity:GetCustomData(DataKeys.Beard, 0)
end

Character.SeleneMethods.setBeard = function(user, beardId)
    user.SeleneEntity:SetCustomData(DataKeys.Beard, beardId)
end

Network.HandlePayload("illarion:use_at", function(player, payload)
    local entity = player.ControlledEntity
    local dimension = entity.Dimension
    local tiles = dimension:GetTilesAt(payload.x, payload.y, payload.z, entity.Collision)
    print(payload.x, payload.y, payload.z)
    for _, tile in pairs(tiles) do
        print(tile.Name)
        local itemId = tile:GetMetadata("itemId")
        if itemId then
            local item = Registries.FindByMetadata("illarion:items", "id", itemId)
            if item then
                local scriptName = item:GetField("script")
                if scriptName then
                    local status, tileScript = pcall(require, "illarion-vbu.server.lua." .. scriptName)
                    if status and type(tileScript.UseItem) == "function" then
                        local illaUser = Character.fromSelenePlayer(player)
                        local illaItem = Item.fromSeleneTile(tile)
                        entity:SetCustomData(DataKeys.LastActionScript, tileScript)
                        entity:SetCustomData(DataKeys.LastActionFunction, tileScript.UseItem)
                        entity:SetCustomData(DataKeys.LastActionArgs, { user, illaItem })
                        tileScript.UseItem(illaUser, illaItem)
                    end
                end
            end
        end
    end
end)

Character.SeleneMethods.introduce = function(user, other)
    user.SeleneEntity:SetCustomData(DataKeys.Introduction .. ":" .. other.id, true)
    -- TODO sync name component
    error("introduce is not fully implemented - does not sync new nameplate yet")
end

Character.SeleneGetters.id = function(user)
    return user.SeleneEntity:GetCustomData(DataKeys.ID, 0)
end

Character.SeleneGetters.name = function(user)
    return user.SeleneEntity.Name
end

Character.SeleneGetters.pos = function(user)
    return user.SeleneEntity.Coordinate
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
    return user:isInRangeToPosition(other.position, distance)
end

Character.SeleneMethods.isInRangeToPosition = function(user, position, distance)
    local dx = math.abs(user.pos.x - position.x)
    local dy = math.abs(user.pos.y - position.y)
    local dz = math.abs(user.pos.z - position.z)
    return (dx <= distance) and (dy <= distance) and dz == 0
end

Character.SeleneMethods.distanceMetric = function(user, other)
    return user:distanceMetricToPosition(other.position)
end

Character.SeleneMethods.distanceMetricToPosition = function(user, position)
    local dx = math.abs(user.pos.x - position.x)
    local dy = math.abs(user.pos.y - position.y)
    local dz = math.abs(user.pos.z - position.z)
    return math.max(dx, dy, dz)
end

Character.SeleneGetters.SeleneEntity = function(user)
    return user.SelenePlayer and user.SelenePlayer.ControlledEntity or rawget(user, "SeleneEntity")
end

function Character.fromSelenePlayer(player)
    return setmetatable({SelenePlayer = player}, Character.SeleneMetatable)
end

function Character.fromSeleneEntity(entity)
    return setmetatable({SeleneEntity = entity}, Character.SeleneMetatable)
end