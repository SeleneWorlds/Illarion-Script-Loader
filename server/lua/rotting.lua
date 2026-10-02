local Schedules = require("selene.schedules")
local RottingManager = require("illarion-script-loader.server.lua.lib.rottingManager")

local AGING_INTERVAL_MS = 3 * 60 * 1000

Schedules.setInterval(AGING_INTERVAL_MS, RottingManager.Tick, { name = "item rotting" })
