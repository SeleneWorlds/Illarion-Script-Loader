local Registries = require("selene.registries")
local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaLearn = require("server.learn")

Character.SeleneMethods.getSkillName = function(skillId)
    local skill = Registries.FindByMetadata("illarion:skills", "id", skillId)
    return skill:GetMetadata("name")
end

Character.SeleneMethods.getSkill = function(user, skillId)
    return user.SeleneEntity():GetCustomData(DataKeys.Skills .. skillId, 0)
end

Character.SeleneMethods.getMinorSkill = function(user, skillId)
    return user.SeleneEntity():GetCustomData(DataKeys.MinorSkills .. skillId, 0)
end

Interface.Skills.SetSkill = function(user, skillId, major)
    user.SeleneEntity():SetCustomData(DataKeys.Skills .. skillId, major)
end

Interface.Skills.SetSkillMinor = function(user, skillId, minor)
    user.SeleneEntity():SetCustomData(DataKeys.MinorSkills .. skillId, minor)
end

Character.SeleneMethods.learn = function(user, skillId, actionPoints, learnLimit)
    illaLearn.learn(user, skillId, actionPoints, learnLimit)
end