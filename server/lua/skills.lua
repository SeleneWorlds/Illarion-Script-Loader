local Schedules = require("selene.schedules")

local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")

local ok, illaLearn = pcall(require, "server.learn")

Schedules.setInterval(10000, function()
    -- TODO I don't like that this holds a Lua-mem list of characters, it's brittle.
    --      Maybe we can have tag-based entity lookups?
    for _, character in pairs(CharacterManager.CharactersById) do
        if illaLearn then
            illaLearn.reduceMC(character)
        end
    end
end)
