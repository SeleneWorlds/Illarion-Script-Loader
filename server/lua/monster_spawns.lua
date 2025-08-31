local Registries = require("selene.registries")

local MonsterSpawn = require("illarion-script-loader.server.lua.lib.monsterSpawn")

local allMonsterSpawns = Registries.FindAll("illarion:monster_spawns")
for _, monsterSpawn in pairs(allMonsterSpawns) do
    local monsterSpawn = MonsterSpawn:new({def = monsterSpawn})
    monsterSpawn:scheduleNext()
end