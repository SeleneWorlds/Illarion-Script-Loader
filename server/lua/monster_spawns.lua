local Registries = require("selene.registries")

local MonsterSpawn = require("illarion-script-loader.server.lua.lib.monsterSpawn")

local function addSpawn(definition)
    local spawn = MonsterSpawn:new({def = definition})
    spawn:scheduleNext()
end

for _, definition in pairs(Registries.findAll("illarion:monster_spawns")) do
    addSpawn(definition)
end

Registries.entryAdded("illarion:monster_spawns"):connect(function(_, definition)
    addSpawn(definition)
end)

Registries.entryChanged("illarion:monster_spawns"):connect(function(identifier, _, definition)
    MonsterSpawn.Remove(identifier)
    addSpawn(definition)
end)

Registries.entryRemoved("illarion:monster_spawns"):connect(function(identifier)
    MonsterSpawn.Remove(identifier)
end)

Registries.reloaded("illarion:monster_spawns"):connect(function()
    MonsterSpawn.RemoveAll()
    for _, definition in pairs(Registries.findAll("illarion:monster_spawns")) do
        addSpawn(definition)
    end
end)
