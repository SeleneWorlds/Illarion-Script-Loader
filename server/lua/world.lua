local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Sounds = require("selene.sounds")
local Interface = require("illarion-api.server.lua.interface")

Interface.World.ShowGFX = function(gfxId, pos)
    local entityType = Registries.FindByMetadata("entities", "gfxId", gfxId)
    if entityType == nil then
        error("Unknown gfx id " .. gfxId)
    end

    local entity = Entities.CreateTransient(entityType.Name)
    entity:SetCoordinate(pos)
    entity:Spawn()
end

Interface.World.PlaySound = function(soundId, pos)
    local sound = Registries.FindByMetadata("sounds", "soundId", soundId)
    if sound ~= nil then
        Sounds.PlaySoundAt(pos.x, pos.y, pos.z, sound.Name)
    end
end
