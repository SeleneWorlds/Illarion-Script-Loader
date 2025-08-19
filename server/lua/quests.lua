local Interface = require("illarion-api.server.lua.interface")

Interface.Quests.GetQuestProgress = function(user, questId)
    return user.SeleneEntity():GetCustomData("illarion:quests:" .. questId, 0)
end

Interface.Quests.SetQuestProgress = function(user, questId, progress)
    user.SeleneEntity():SetCustomData("illarion:quests:" .. questId, progress)
end