local Registries = require("selene.registries")
local Entities = require("selene.entities")
local Schedules = require("selene.schedules")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local NPCManager

local allNPCs = Registries.FindAll("illarion:npcs")
for _, npc in pairs(allNPCs) do
    NPCManager.Spawn(npc)
end

Schedules.SetInterval(100, function()
    NPCManager.Update()
end)