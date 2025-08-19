local Entities = require("selene.entities")
local Network = require("selene.network")
local Interface = require("illarion-api.server.lua.interface")

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
