local Registries = require("selene.registries")
local Interface = require("illarion-api.server.lua.interface")

local illaLearn = require("server.learn")

Interface.Skills.GetSkillName = function(skillId)
    local skill = Registries.FindByMetadata("illarion:skills", "id", tostring(skillId))
    return skill:GetMetadata("name")
end

Interface.Skills.GetSkill = function(user, skillId)
    return User.SeleneEntity():GetCustomData("illarion:skills:" .. skillId, 0)
end

Interface.Skills.GetMinorSkill = function(user, skillId)
    return User.SeleneEntity():GetCustomData("illarion:skills:" .. skillId .. ":minor", 0)
end

Interface.Skills.SetSkill = function(user, skillId, major)
    User.SeleneEntity():SetCustomData("illarion:skills:" .. skillId, major)
end

Interface.Skills.SetSkillMinor = function(user, skillId, minor)
    User.SeleneEntity():SetCustomData("illarion:skills:" .. skillId .. ":minor", minor)
end

Interface.Skills.Learn = function(user, skillId, actionPoints, learnLimit)
    illaLearn.learn(user, skillId, actionPoints, learnLimit)
end