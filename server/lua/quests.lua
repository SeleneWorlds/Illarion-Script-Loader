local Interface = require("illarion-api.server.lua.interface")

Interface.Quests.GetQuestProgress = function(user, questId)
    return User.SeleneEntity():GetCustomData("illarion:quests:" .. questId, 0)
end

Interface.Quests.SetQuestProgress = function(user, questId, progress)
    User.SeleneEntity():SetCustomData("illarion:quests:" .. questId, progress)
end