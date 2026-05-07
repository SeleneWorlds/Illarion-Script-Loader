local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getQuestProgress = function(user, questId)
    local quests = user.SeleneEntity:getRuntimeData(DataKeys.Quests)
    return quests[questId] or 0
end

Character.SeleneMethods.setQuestProgress = function(user, questId, progress)
    local quests = user.SeleneEntity:getRuntimeData(DataKeys.Quests)
    quests[questId] = progress
end