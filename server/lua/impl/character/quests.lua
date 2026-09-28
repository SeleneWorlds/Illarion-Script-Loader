local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getQuestProgress = function(user, questId)
    local quests = user.SeleneEntity:getRuntimeData(DataKeys.Quests)
    local quest = quests[questId]
    if quest then
        return quest.progress, quest.time
    end
    return 0, 0
end

Character.SeleneMethods.setQuestProgress = function(user, questId, progress)
    local quests = user.SeleneEntity:getRuntimeData(DataKeys.Quests)
    quests[questId] = {
        progress = progress,
        time = os.time()
    }
end
