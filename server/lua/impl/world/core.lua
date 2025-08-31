local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Sounds = require("selene.sounds")

world.SeleneMethods.gfx = function(world, gfxId, pos)
    local entityType = Registries.FindByMetadata("entities", "gfxId", gfxId)
    if entityType == nil then
        print("Unknown gfx id " .. gfxId)
        return
    end

    local entity = Entities.CreateTransient(entityType)
    entity:SetCoordinate(pos)
    entity:Spawn()
end

world.SeleneMethods.makeSound = function(world, soundId, pos)
    local sound = Registries.FindByMetadata("sounds", "soundId", soundId)
    if sound ~= nil then
        Sounds.PlaySoundAt(pos.x, pos.y, pos.z, sound)
    end
end
