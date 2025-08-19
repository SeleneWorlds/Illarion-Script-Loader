local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Interface.Chat.Talk = function(user, mode, message, messageEnglish)
    print("Talk", user.name, mode, message, messageEnglish)
    local entity = user.SeleneEntity()
    entity:SetCustomData(DataKeys.LastSpokenText, message)
end

Interface.Chat.GetLanguage = function(user)
    local entity = user.SeleneEntity()
    return entity:GetCustomData(DataKeys.Language, 0)
end

Interface.Chat.SetLanguage = function(user, language)
    entity:SetCustomData(DataKeys.Language, language)
end

Interface.Chat.GetLastSpokenText = function(user)
    return entity:GetCustomData(DataKeys.LastSpokenText, "")
end