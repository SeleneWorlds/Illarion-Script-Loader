local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Sounds = require("selene.sounds")

world.SeleneMethods.gfx = function(world, gfxId, pos)
    gfxId = assert(tonumber(gfxId), "gfxId must be a number, was " .. tostring(gfxId))
    local entityType = Registries.findByMetadata("entities", "gfxId", gfxId)
    if entityType == nil then
        print("Unknown gfx id " .. gfxId)
        return
    end

    local entity = Entities.createTransient(entityType)
    entity:setCoordinate(pos)
    entity:spawn()
end

world.SeleneMethods.makeSound = function(world, soundId, pos)
    soundId = assert(tonumber(soundId), "soundId must be a number, was " .. tostring(soundId))
    local sound = Registries.findByMetadata("sounds", "soundId", soundId)
    if sound ~= nil then
        Sounds.playSoundAt(pos.x, pos.y, pos.z, sound)
    end
end
