local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getQuestProgress = function(user, questId)
    return user.SeleneEntity():GetCustomData(DataKeys.Quests .. questId, 0)
end

Character.SeleneMethods.setQuestProgress = function(user, questId, progress)
    user.SeleneEntity():SetCustomData(DataKeys.Quests .. questId, progress)
end