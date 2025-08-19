local Registries = require("selene.registries")
local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaLearn = require("server.learn")

Interface.Skills.GetSkillName = function(skillId)
    local skill = Registries.FindByMetadata("illarion:skills", "skillId", skillId)
    return skill:GetMetadata("name")
end

Interface.Skills.GetSkill = function(user, skillId)
    return user.SeleneEntity():GetCustomData(DataKeys.Skills .. skillId, 0)
end

Interface.Skills.GetMinorSkill = function(user, skillId)
    return user.SeleneEntity():GetCustomData(DataKeys.MinorSkills .. skillId, 0)
end

Interface.Skills.SetSkill = function(user, skillId, major)
    user.SeleneEntity():SetCustomData(DataKeys.Skills .. skillId, major)
end

Interface.Skills.SetSkillMinor = function(user, skillId, minor)
    user.SeleneEntity():SetCustomData(DataKeys.MinorSkills .. skillId, minor)
end

Interface.Skills.Learn = function(user, skillId, actionPoints, learnLimit)
    illaLearn.learn(user, skillId, actionPoints, learnLimit)
end