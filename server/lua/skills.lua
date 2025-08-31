local Schedules = require("selene.schedules")

local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")

local illaLearn = require("server.learn")

Schedules.SetInterval(10000, function()
    for _, character in pairs(CharacterManager.CharactersById) do
        illaLearn.reduceMC(character)
    end
end)
