local Registries = require("selene.registries")

local SkillManager = require("illarion-script-loader.server.lua.lib.skillManager")

Character.SeleneMethods.getSkillName = function(skillId)
    local skill = Registries.findByMetadata("illarion:skills", "id", skillId)
    return skill:getMetadata("name")
end

Character.SeleneMethods.getSkill = function(user, skillId)
    return SkillManager.GetMajorSkillAttribute(user, skillId):getEffectiveValue()
end

Character.SeleneMethods.getMinorSkill = function(user, skillId)
    return SkillManager.GetMinorSkillAttribute(user, skillId):getEffectiveValue()
end

Character.SeleneMethods.increaseSkill = function(user, skillGroupOrSkillId, skillIdOrAmount, amountOrNil)
    local amount = type(skillIdOrAmount) == "number" and skillIdOrAmount or amountOrNil
    local skillId = type(skillIdOrAmount) == "number" and skillGroupOrSkillId or skillIdOrAmount
    local attribute = SkillManager.GetMajorSkillAttribute(user, skillId)
    attribute:setValue(attribute:getValue() + amount)
    return attribute:getEffectiveValue()
end

Character.SeleneMethods.increaseMinorSkill = function(user, skillId, amount)
    local attribute = SkillManager.GetMinorSkillAttribute(user, skillId)
    local newValue = attribute:getValue() + amount
    if newValue > 10000 then
        user:increaseSkill(skillId, 1)
        newValue = 0
    end
    attribute:setValue(newValue)
    return user:getSkill(skillId)
end

Character.SeleneMethods.setSkill = function(user, skillId, major, minor)
    SkillManager.GetMajorSkillAttribute(user, skillId):setValue(major)
    SkillManager.GetMinorSkillAttribute(user, skillId):setValue(minor)
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