local Registries = require("selene.registries")
local Server = require("selene.server")
local Events = require("illarion-script-loader.server.lua.lib.events")
local Behaviors = require("moonlight-behaviors.server.lua.behaviors")
local BehaviorDefaults = require("illarion-script-loader.server.lua.lib.behaviorDefaults")

local M = {}
local behaviors = BehaviorDefaults.registerBehaviorDefaults(Behaviors:new())

---Dispatch to all enabled global behavior entries, without a location filter.
---Resolve entries on every emission so registry edits take effect immediately.
function M.emit(event, context)
    for _, entry in pairs(Registries.findAll("illarion:behaviors")) do
        if entry:getField("enabled") == true then
            behaviors:emit(event, entry:getField("behaviors") or {}, context)
        end
    end
end

local function initialize()
    for _, entry in pairs(Registries.findAll("illarion:behaviors")) do
        if entry:getField("enabled") == true then
            behaviors:emit("init", entry:getField("behaviors") or {}, { globalBehavior = entry })
        end
    end
end

Events.onUseItem:connect(function(context)
    M.emit("use_item", context)
end)

Events.onLookAtItem:connect(function(context)
    M.emit("look_at_item", context)
end)

initialize()
Server.serverReloaded:connect(initialize)
Registries.entryAdded("illarion:behaviors"):connect(initialize)
Registries.entryChanged("illarion:behaviors"):connect(initialize)
Registries.entryRemoved("illarion:behaviors"):connect(initialize)
Registries.reloaded("illarion:behaviors"):connect(initialize)

return M
