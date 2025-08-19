local Entities = require("selene.entities")
local Network = require("selene.network")
local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Interface.Character.GetType = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.CharacterType, Character.player)
end

Interface.Character.GetRace = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.Race, 0)
end

Interface.Character.SetRace = function(user, raceId)
    user.SeleneEntity():SetCustomData(DataKeys.Race, raceId)
end

Interface.Character.GetSkinColor = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.SkinColor, colour(255, 255, 255))
end

Interface.Character.SetSkinColor = function(user, skinColor)
    user.SeleneEntity():SetCustomData(DataKeys.SkinColor, skinColor)
end

Interface.Character.GetHairColor = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.HairColor, colour(255, 255, 255))
end

Interface.Character.SetHairColor = function(user, hairColor)
    user.SeleneEntity():SetCustomData(DataKeys.HairColor, hairColor)
end

Interface.Character.GetHair = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.Hair, 0)
end

Interface.Character.SetHair = function(user, hairId)
    user.SeleneEntity():SetCustomData(DataKeys.Hair, hairId)
end

Interface.Character.GetBeard = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.Beard, 0)
end

Interface.Character.SetBeard = function(user, beardId)
    user.SeleneEntity():SetCustomData(DataKeys.Beard, beardId)
end

Entities.SteppedOnTile:Connect(function(entity, coordinate)
    local warpAnnotation = entity:CollisionMap(coordinate):GetAnnotation(coordinate, "illarion:warp")
    if warpAnnotation then
        entity:SetCoordinate(warpAnnotation.ToX, warpAnnotation.ToY, warpAnnotation.ToLevel)
    end
end)

Network.HandlePayload("illarion:use_at", function(player, payload)
    local entity = player:GetControlledEntity()
    local dimension = entity.Dimension
    local tiles = dimension:GetTilesAt(payload.x, payload.y, payload.z, entity.Collision)
    for _, tile in pairs(tiles) do
        local tileScriptName = tile:GetMetadata("script")
        if tileScriptName and tileScriptName ~= "\\N" then
            local status, tileScript = pcall(require, "illarion-vbu.server.lua." .. tileScriptName)
            if status and type(tileScript.UseItem) == "function" then
                tileScript.UseItem(Character.fromSelenePlayer(player), Item.fromSeleneTile(tile))
            end
        end
    end
end)
