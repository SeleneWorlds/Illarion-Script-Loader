local Registries = require("selene.registries")
local Entities = require("selene.entities")
local DirectionUtils = require("illarion-api.server.lua.lib.directionUtils")

local allNPCs = Registries.FindAll("illarion:npcs")
for _, npc in ipairs(allNPCs) do
    local race = Registries.FindByMetadata("illarion:races", "raceId", npc:GetField("type"))
    if race then
        local sex = npc:GetField("sex") == 1 and "Female" or "Male"
        local entityName = race:GetField("entity" .. sex)
        if entityName then
            local entity = Entities.Create(entityName)
            entity.Name = npc:GetField("name")
            entity:SetCoordinate(npc:GetField("x"), npc:GetField("y"), npc:GetField("z"))
            entity:SetFacing(DirectionUtils.IllaToSelene(npc:GetField("facing")))
            entity:Spawn()
        else
            print("No entity for race " .. npc:GetField("type") .. " and sex " .. npc:GetField("sex"))
        end
    else
        print("No race for npc " .. npc:GetField("name"))
    end
end
