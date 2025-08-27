local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getQuestProgress = function(user, questId)
    return user.SeleneEntity.CustomData[DataKeys.Quest(questId)] or 0
end

Character.SeleneMethods.setQuestProgress = function(user, questId, progress)
    user.SeleneEntity.CustomData[DataKeys.Quest(questId)] = progress
end