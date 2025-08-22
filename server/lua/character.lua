local Network = require("selene.network")
local Registries = require("selene.registries")
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
