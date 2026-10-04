local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getQuestProgress = function(user, questId)
    questId = assert(tonumber(questId), "questId must be a number, was " .. tostring(questId))
    local quests = user.SeleneEntity:getRuntimeData(DataKeys.Quests)
    local quest = quests[questId]
    if quest then
        return quest.progress, quest.time
    end
    return 0, 0
end

Character.SeleneMethods.setQuestProgress = function(user, questId, progress)
    questId = assert(tonumber(questId), "questId must be a number, was " .. tostring(questId))
    progress = assert(tonumber(progress), "progress must be a number, was " .. tostring(progress))
    local quests = user.SeleneEntity:getRuntimeData(DataKeys.Quests)
    quests[questId] = {
        progress = progress,
        time = os.time()
    }
end
