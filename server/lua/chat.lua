local Network = require("selene.network")

Network.HandlePayload("illarion:chat", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local mode = Character.say
    if payload.mode == "whisper" then
        mode = Character.whisper
    elseif payload.mode == "yell" then
        mode = Character.yell
    end
    character:talk(mode, payload.message)
end)