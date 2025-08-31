local Registries = require("selene.registries")

local SkillManager = require("illarion-script-loader.server.lua.lib.skillManager")

Character.SeleneMethods.getSkillName = function(skillId)
    local skill = Registries.FindByMetadata("illarion:skills", "id", skillId)
    return skill:GetMetadata("name")
end

Character.SeleneMethods.getSkill = function(user, skillId)
    return SkillManager.GetMajorSkillAttribute(user, skillId).EffectiveValue
end

Character.SeleneMethods.getMinorSkill = function(user, skillId)
    return SkillManager.GetMinorSkillAttribute(user, skillId).EffectiveValue
end

Character.SeleneMethods.increaseSkill = function(user, skillId, amount)
    local attribute = SkillManager.GetMajorSkillAttribute(user, skillId)
    attribute.Value = attribute.Value + amount
    return attribute.EffectiveValue
end

Character.SeleneMethods.increaseMinorSkill = function(user, skillId, amount)
    local attribute = SkillManager.GetMinorSkillAttribute(user, skillId)
    local newValue = attribute.Value + amount
    if newValue > 10000 then
        user:increaseSkill(skillId, 1)
        newValue = 0
    end
    attribute.Value = newValue
    return user:getSkill(skillId)
end

Character.SeleneMethods.setSkill = function(user, skillId, major, minor)
    SkillManager.GetMajorSkillAttribute(user, skillId).Value = major
    SkillManager.GetMinorSkillAttribute(user, skillId).Value = minor
end

Character.SeleneMethods.learn = function(user, skillId, actionPoints, learnLimit)
    require("server.learn").learn(user, skillId, actionPoints, learnLimit)
end

Character.SeleneMethods.getSkillValue = function(user, skillId)
     return {
         major = user:getSkill(skillId),
         minor = user:getMinorSkill(skillId)
     }
end