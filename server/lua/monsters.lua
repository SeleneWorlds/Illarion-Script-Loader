local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local MonsterManager = require("illarion-script-loader.server.lua.lib.monsterManager")

Schedules.setInterval(100, function()
    MonsterManager.Update()
end)

Registries.entryChanged("illarion:monsters"):connect(function(identifier)
    MonsterManager.ReloadDefinitions(identifier)
end)
Registries.entryRemoved("illarion:monsters"):connect(function(identifier)
    MonsterManager.ReloadDefinitions(identifier)
end)
Registries.reloaded("illarion:monsters"):connect(function()
    MonsterManager.ReloadDefinitions()
end)
