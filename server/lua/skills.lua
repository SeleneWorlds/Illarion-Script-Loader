local Schedules = require("selene.schedules")
local Entities = require("selene.entities")

local illaLearnOk, illaLearn = xpcall(require, "server.learn")

Schedules.setInterval(10000, function()
    for _, entity in ipairs(Entities.byTag("illarion:character")) do
        if illaLearnOk then
            local character = Character.fromSeleneEntity(entity)
            if character:getMentalCapacity() > 0 then
                illaLearn.reduceMC()
            end
        end
    end
end)
