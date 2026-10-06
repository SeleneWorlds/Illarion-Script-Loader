local Schedules = require("selene.schedules")
local Entities = require("selene.entities")

local illaLearnOk, illaLearn = xpcall(require, "server.learn")

Schedules.setInterval(10000, function()
    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        if illaLearnOk then
            illaLearn.reduceMC(Character.fromSeleneEntity(entity))
        end
    end
end)
