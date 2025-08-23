local Entities = require("selene.entities")

Entities.SteppedOnTile:Connect(function(entity, coordinate)
    local warpAnnotation = entity:CollisionMap(coordinate):GetAnnotation(coordinate, "illarion:warp")
    if warpAnnotation then
        entity:SetCoordinate(warpAnnotation.ToX, warpAnnotation.ToY, warpAnnotation.ToLevel)
    end
end)