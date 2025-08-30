local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local NPCManager = require("illarion-script-loader.server.lua.lib.npcManager")

local allNPCs = Registries.FindAll("illarion:npcs")
for _, npc in pairs(allNPCs) do
    NPCManager.Spawn(npc)
end

Schedules.SetInterval(100, function()
    NPCManager.Update()
end)