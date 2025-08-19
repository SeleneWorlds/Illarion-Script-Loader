local Interface = require("illarion-api.server.lua.interface")

Interface.Chat.Talk = function(user, mode, message, messageEnglish)
    print("Talk", user.name, mode, message, messageEnglish)
    local entity = user.SeleneEntity()
    entity:SetCustomData("illarion:lastSpokenText", message)
end

Interface.Chat.GetLanguage = function(user)
    local entity = user.SeleneEntity()
    return entity:GetCustomData("illarion:language", 0)
end

Interface.Chat.SetLanguage = function(user, language)
    entity:SetCustomData("illarion:language", language)
end

Interface.Chat.GetLastSpokenText = function(user)
    return entity:GetCustomData("illarion:lastSpokenText", "")
end