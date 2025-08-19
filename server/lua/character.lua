local Entities = require("selene.entities")
local Network = require("selene.network")
local Interface = require("illarion-api.server.lua.interface")

Interface.Character.GetRace = function(user)
    return user.SeleneEntity():GetCustomData("illarion:race", 0)
end

Interface.Character.SetRace = function(user, raceId)
    user.SeleneEntity():SetCustomData("illarion:race", raceId)
end

Interface.Character.GetSkinColor = function(user)
    return user.SeleneEntity():GetCustomData("illarion:skinColor", colour(255, 255, 255))
end

Interface.Character.SetSkinColor = function(user, skinColor)
    user.SeleneEntity():SetCustomData("illarion:skinColor", skinColor)
end

Interface.Character.GetHairColor = function(user)
    return user.SeleneEntity():GetCustomData("illarion:hairColor", colour(255, 255, 255))
end

Interface.Character.SetHairColor = function(user, hairColor)
    user.SeleneEntity():SetCustomData("illarion:hairColor", hairColor)
end

Interface.Character.GetHair = function(user)
    return user.SeleneEntity():GetCustomData("illarion:hair", 0)
end

Interface.Character.SetHair = function(user, hairId)
    user.SeleneEntity():SetCustomData("illarion:hair", hairId)
end

Interface.Character.GetBeard = function(user)
    return user.SeleneEntity():GetCustomData("illarion:beard", 0)
end

Interface.Character.SetBeard = function(user, beardId)
    user.SeleneEntity():SetCustomData("illarion:beard", beardId)
end

Entities.SteppedOnTile:Connect(function(Entity, Coordinate)
    local warpAnnotation = Entity:CollisionMap(Coordinate):GetAnnotation(Coordinate, "illarion:warp")
    if warpAnnotation then
        Entity:SetCoordinate(warpAnnotation.ToX, warpAnnotation.ToY, warpAnnotation.ToLevel)
    end
end)

Network.HandlePayload("illarion:use_at", function(Player, Payload)
    local entity = Player:GetControlledEntity()
    local dimension = entity.Dimension
    local tiles = dimension:GetTilesAt(Payload.x, Payload.y, Payload.z, entity.Collision)
    for _, tile in pairs(tiles) do
        local tileScriptName = tile:GetMetadata("script")
        if tileScriptName and tileScriptName ~= "\\N" then
            local status, tileScript = pcall(require, "illarion-vbu.server.lua." .. tileScriptName)
            if status and type(tileScript.UseItem) == "function" then
                tileScript.UseItem(Character.fromSelenePlayer(Player), Item.fromSeleneTile(tile))
            end
        end
    end
end)
