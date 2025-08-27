local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaLearn = require("server.learn")

Character.SeleneMethods.getSkillName = function(skillId)
    local skill = Registries.FindByMetadata("illarion:skills", "id", skillId)
    return skill:GetMetadata("name")
end

Character.SeleneMethods.getSkill = function(user, skillId)
    return user.SeleneEntity.CustomData[DataKeys.Skills .. skillId] or 0
end

Character.SeleneMethods.getMinorSkill = function(user, skillId)
    return user.SeleneEntity.CustomData[DataKeys.MinorSkills .. skillId] or 0
end

Character.SeleneMethods.increaseSkill = function(user, skillId, amount)
    local skill = user.SeleneEntity.CustomData[DataKeys.Skills .. skillId] or 0
    skill = skill + amount
    user.SeleneEntity.CustomData[DataKeys.Skills .. skillId] = skill
end

Character.SeleneMethods.increaseMinorSkill = function(user, skillId, amount)
    local skill = user.SeleneEntity.CustomData[DataKeys.MinorSkills .. skillId] or 0
    skill = skill + amount
    user.SeleneEntity.CustomData[DataKeys.MinorSkills .. skillId] = skill
end

Character.SeleneMethods.setSkill = function(user, skillId, major, minor)
    user.SeleneEntity.CustomData[DataKeys.Skills .. skillId] = major
    user.SeleneEntity.CustomData[DataKeys.MinorSkills .. skillId] = minor
end

Character.SeleneMethods.learn = function(user, skillId, actionPoints, learnLimit)
    illaLearn.learn(user, skillId, actionPoints, learnLimit)
end

Character.SeleneMethods.getSkillValue = function(user, skillId)
     return {
         major = user:getSkill(skillId),
         minor = user:getMinorSkill(skillId)
     }
end