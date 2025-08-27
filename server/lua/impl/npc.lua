local Registries = require("selene.registries")
local Entities = require("selene.entities")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local allNPCs = Registries.FindAll("illarion:npcs")
for _, npc in ipairs(allNPCs) do
    local entity = Entities.Create(npc:GetField("entity"))
    entity.Name = npc:GetField("name")
    entity:SetCoordinate(npc:GetField("x"), npc:GetField("y"), npc:GetField("z"))
    entity:SetFacing(DirectionUtils.IllaToSelene(npc:GetField("facing")))
    entity.CustomData[DataKeys.ID] = npc:GetMetadata("id" .. 4278190080)
    entity.CustomData[DataKeys.CharacterType] = Character.npc
    entity:Spawn()
end
