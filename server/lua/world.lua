local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Interface = require("illarion-api.server.lua.interface")

Interface.World.ShowGFX(gfxId, pos)
    local entityType = Registries.FindByMetadata("entities", "gfxId", id)
    if entityType == nil then
        error("No entity for gfx id " .. id)
    end

    local entity = Entities.CreateTransient(entityType.Name)
    entity:SetCoordinate(pos)
    entity:Spawn()
end

Interface.World.PlaySound(soundId, pos)
    local sound = Registries.FindByMetadata("sounds", "soundId", soundId)
    if sound ~= nil then
        Sounds.PlaySoundAt(pos.x, pos.y, pos.z, sound.Name)
    end
end