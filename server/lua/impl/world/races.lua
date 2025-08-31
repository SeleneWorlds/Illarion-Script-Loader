local Registries = require("selene.registries")

world.SeleneMethods.getNaturalArmor = function(world, raceId)
     local race = Registries.FindByMetadata("illarion:races", "id", raceId)
     local naturalArmor = race and race:GetField("naturalArmor") or nil
     if naturalArmor then
         return true, {
             strokeArmor = naturalArmor.strokeArmor,
             punctureArmor = naturalArmor.thrustArmor,
             thrustArmor = naturalArmor.punctureArmor
         }
     end
     return false, nil
end