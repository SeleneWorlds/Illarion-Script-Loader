local Registries = require("selene.registries")
local Entities = require("selene.entities")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local allNPCs = Registries.FindAll("illarion:npcs")
for _, npc in pairs(allNPCs) do
    local race = Registries.FindByName("illarion:races", npc:GetField("race"))
    if race == nil then
        error("Unknown race " .. npc:GetField("race") .. " for NPC " .. npc.Name)
    end
    local entity = Entities.Create(npc:GetField("entity"))
    entity.Name = npc:GetField("name")
    entity:SetCoordinate(npc:GetField("x"), npc:GetField("y"), npc:GetField("z"))
    entity:SetFacing(DirectionUtils.IllaToSelene(npc:GetField("facing")))
    entity.CustomData[DataKeys.ID] = npc:GetMetadata("id" .. 4278190080)
    entity.CustomData[DataKeys.CharacterType] = Character.npc
    entity.CustomData[DataKeys.NPC] = npc
    entity.CustomData[DataKeys.Race] = race
    entity.CustomData[DataKeys.Sex] = npc:GetField("sex") == 1 and "female" or "male"
    entity:Spawn()
end
