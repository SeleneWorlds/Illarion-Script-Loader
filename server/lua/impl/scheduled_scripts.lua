local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local scheduledCallbacks = {}

function scheduleNext(scheduledScript)
    local interval = math.random(scheduledScript:GetField("minInterval"), scheduledScript:GetField("maxInterval"))
    Schedules.SetTimeout(interval * 1000, scheduledCallbacks[scheduledScript.Name])
end

local allScheduledScripts = Registries.FindAll("illarion:scheduled_scripts")
for _, scheduledScript in pairs(allScheduledScripts) do
    scheduledCallbacks[scheduledScript.Name] = function()
       local scriptName = scheduledScript:GetField("script")
       local functionName = scheduledScript:GetField("function")
       local status, script = pcall(require, scriptName)
       if status and type(script[functionName]) == "function" then
           script[functionName]()
           scheduleNext(scheduledScript)
       end
    end
    scheduleNext(scheduledScript)
end