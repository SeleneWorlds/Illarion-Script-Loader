local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local scheduledCallbacks = {}

function scheduleNext(scheduledScript)
    local interval = math.random(scheduledScript:getField("minInterval"), scheduledScript:getField("maxInterval"))
    Schedules.setTimeout(interval * 1000, scheduledCallbacks[scheduledScript:getName()])
end

local allScheduledScripts = Registries.findAll("illarion:scheduled_scripts")
for _, scheduledScript in pairs(allScheduledScripts) do
    scheduledCallbacks[scheduledScript:getName()] = function()
       local scriptName = scheduledScript:getField("script")
       local functionName = scheduledScript:getField("function")
       local status, script = pcall(require, scriptName)
       if status and type(script[functionName]) == "function" then
           script[functionName]()
           scheduleNext(scheduledScript)
       end
    end
    scheduleNext(scheduledScript)
end