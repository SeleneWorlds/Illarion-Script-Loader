local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local NPCManager = require("illarion-script-loader.server.lua.lib.npcManager")

local allNPCs = Registries.findAll("illarion:npcs")
for _, npc in pairs(allNPCs) do
    NPCManager.Spawn(npc)
end

Registries.entryAdded("illarion:npcs"):connect(function(_, npc)
    NPCManager.Spawn(npc)
end)

Registries.entryChanged("illarion:npcs"):connect(function(identifier, _, newNpc)
    NPCManager.RemoveStatic(identifier)
    NPCManager.Spawn(newNpc)
end)

Registries.entryRemoved("illarion:npcs"):connect(function(identifier)
    NPCManager.RemoveStatic(identifier)
end)

Registries.reloaded("illarion:npcs"):connect(function()
    NPCManager.RemoveAllStatic()
    for _, npc in pairs(Registries.findAll("illarion:npcs")) do
        NPCManager.Spawn(npc)
    end
end)

Schedules.setInterval(100, function()
    NPCManager.Update()
end)
