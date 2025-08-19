local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Interface.Quests.GetQuestProgress = function(user, questId)
    return user.SeleneEntity():GetCustomData(DataKeys.Quests .. questId, 0)
end

Interface.Quests.SetQuestProgress = function(user, questId, progress)
    user.SeleneEntity():SetCustomData(DataKeys.Quests .. questId, progress)
end