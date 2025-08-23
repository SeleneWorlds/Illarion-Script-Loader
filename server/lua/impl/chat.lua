local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.talk = function(user, mode, message, messageEnglish)
    print("Talk", user.name, mode, message, messageEnglish)
    local entity = user.SeleneEntity
    entity:SetCustomData(DataKeys.LastSpokenText, message)
end

Character.SeleneGetters.activeLanguage = function(user)
    local entity = user.SeleneEntity
    return entity:GetCustomData(DataKeys.Language, 0)
end

Character.SeleneSetters.activeLanguage = function(user, language)
    entity:SetCustomData(DataKeys.Language, language)
end

Character.SeleneGetters.lastSpokenText = function(user)
    return entity:GetCustomData(DataKeys.LastSpokenText, "")
end

world.broadcast = function(world, messageDe, messageEn)
    local players = Players.GetOnlinePlayers()
    for _,player in ipairs(players) do
        if user.SelenePlayer.Language == "de" then
            Network.SendToPlayer(user.SelenePlayer, "illarion:inform", { Message = messageDe })
        else
            Network.SendToPlayer(user.SelenePlayer, "illarion:inform", { Message = messageEn })
        end
    end
end