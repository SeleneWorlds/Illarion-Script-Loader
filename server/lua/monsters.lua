local Schedules = require("selene.schedules")

local MonsterManager = require("illarion-script-loader.server.lua.lib.monsterManager")

Schedules.SetInterval(100, function()
    MonsterManager.Update()
end)