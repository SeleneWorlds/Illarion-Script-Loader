local Network = require("selene.network")
local AdminCommands = require("illarion-script-loader.server.lua.admin_commands")

Network.handlePayload("illarion:chat", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    if AdminCommands.handle(character, payload.message) then
        return
    end
    local mode = Character.say
    if payload.mode == "whisper" then
        mode = Character.whisper
    elseif payload.mode == "yell" then
        mode = Character.yell
    end
    character:talk(mode, payload.message)
end)
