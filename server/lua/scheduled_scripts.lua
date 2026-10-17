local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local Behaviors = require("moonlight-behaviors.server.lua.behaviors")
local BehaviorDefaults = require("illarion-script-loader.server.lua.lib.behaviorDefaults")

local behaviors = BehaviorDefaults.registerBehaviorDefaults(Behaviors:new())
local schedules = {}

local function removeSchedule(identifier)
    local schedule = schedules[identifier]
    if schedule then
        schedule.stopped = true
        if schedule.timeoutId then
            Schedules.clearTimeout(schedule.timeoutId)
        end
        schedules[identifier] = nil
    end
end

local function addSchedule(definition)
    local identifier = definition:getName()
    removeSchedule(identifier)
    if definition:getField("enabled") ~= true then return end
    local schedule = { definition = definition }
    schedules[identifier] = schedule
    local function scheduleNext()
        if schedule.stopped then return end
        local intervalRange = definition:getField("interval")
        local interval = math.random(intervalRange.min, intervalRange.max)
        schedule.timeoutId = Schedules.setTimeout(interval * 1000, function()
            schedule.timeoutId = nil
            if schedule.stopped then return end
            behaviors:emit("tick", definition:getField("behaviors") or {}, { scheduledScript = definition })
            local scriptName = definition:getField("script")
            if scriptName and scriptName ~= "" then
                local status, script = xpcall(require, debug.traceback, scriptName)
                local functionName = definition:getField("function")
                if status and type(script[functionName]) == "function" then
                    script[functionName](definition)
                else
                    return
                end
            end
            scheduleNext()
        end, { name = identifier })
    end
    scheduleNext()
end

local function reloadSchedules()
    local identifiers = {}
    for identifier in pairs(schedules) do
        identifiers[#identifiers + 1] = identifier
    end
    for _, identifier in ipairs(identifiers) do removeSchedule(identifier) end
    for _, definition in pairs(Registries.findAll("illarion:scheduled_scripts")) do
        addSchedule(definition)
    end
end

reloadSchedules()
Registries.entryAdded("illarion:scheduled_scripts"):connect(function(_, definition)
    addSchedule(definition)
end)
Registries.entryChanged("illarion:scheduled_scripts"):connect(function(identifier, _, definition)
    removeSchedule(identifier)
    addSchedule(definition)
end)
Registries.entryRemoved("illarion:scheduled_scripts"):connect(removeSchedule)
Registries.reloaded("illarion:scheduled_scripts"):connect(reloadSchedules)
