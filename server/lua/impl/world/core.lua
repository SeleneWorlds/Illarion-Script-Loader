local Registries = require("selene.registries")
local Sounds = require("selene.sounds")
local Timelines = require("selene.timelines")

world.SeleneMethods.gfx = function(world, gfxId, pos)
    gfxId = assert(tonumber(gfxId), "gfxId must be a number, was " .. tostring(gfxId))
    local entityType = Registries.findByMetadata("entities", "gfxId", gfxId)
    if entityType == nil then
        print("Unknown gfx id " .. gfxId)
        return
    end

    Timelines.playAt(pos.x, pos.y, pos.z, "illarion:gfx/gfx_" .. gfxId)
end

world.SeleneMethods.makeSound = function(world, soundId, pos)
    soundId = assert(tonumber(soundId), "soundId must be a number, was " .. tostring(soundId))
    local sound = Registries.findByMetadata("sounds", "soundId", soundId)
    if sound ~= nil then
        Sounds.playSoundAt(pos.x, pos.y, pos.z, sound)
    end
end
