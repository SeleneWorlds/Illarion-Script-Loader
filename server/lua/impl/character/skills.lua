local Registries = require("selene.registries")

local SkillManager = require("illarion-script-loader.server.lua.lib.skillManager")

local function resolveSkillId(skillIdOrName)
    if type(skillIdOrName) == "string" then
        return Character[skillIdOrName]
    end
    return skillIdOrName
end

Character.SeleneMethods.getSkillName = function(skillId)
    skillId = resolveSkillId(skillId)
    local skill = Registries.findByMetadata("illarion:skills", "id", skillId)
    return skill:getMetadata("name")
end

Character.SeleneMethods.getSkill = function(user, skillId)
    skillId = resolveSkillId(skillId)
    return SkillManager.GetMajorSkillAttribute(user, skillId):getEffectiveValue()
end

Character.SeleneMethods.getMinorSkill = function(user, skillId)
    skillId = resolveSkillId(skillId)
    return SkillManager.GetMinorSkillAttribute(user, skillId):getEffectiveValue()
end

Character.SeleneMethods.increaseSkill = function(user, skillGroupOrSkillId, skillIdOrAmount, amountOrNil)
    local amount = type(skillIdOrAmount) == "number" and skillIdOrAmount or amountOrNil
    local skillId = type(skillIdOrAmount) == "number" and skillGroupOrSkillId or skillIdOrAmount
    skillId = resolveSkillId(skillId)
    local attribute = SkillManager.GetMajorSkillAttribute(user, skillId)
    attribute:setValue(attribute:getValue() + amount)
    return attribute:getEffectiveValue()
end

Character.SeleneMethods.increaseMinorSkill = function(user, skillId, amount)
    skillId = resolveSkillId(skillId)
    local attribute = SkillManager.GetMinorSkillAttribute(user, skillId)
    local newValue = attribute:getValue() + amount
    if newValue >= 10000 then
        user:increaseSkill(skillId, 1)
        newValue = newValue - 10000
    end
    attribute:setValue(newValue)
    return user:getSkill(skillId)
end

Character.SeleneMethods.setSkill = function(user, skillId, major, minor)
    skillId = resolveSkillId(skillId)
    SkillManager.GetMajorSkillAttribute(user, skillId):setValue(major)
    SkillManager.GetMinorSkillAttribute(user, skillId):setValue(minor)
end

Character.SeleneMethods.learn = function(user, skillGroupOrSkillId, skillIdOrActionPoints, actionPointsOrLearnLimit, learnLimitOrNil)
    local skillId
    local actionPoints
    local learnLimit
    if learnLimitOrNil ~= nil then
        skillId = skillIdOrActionPoints
        actionPoints = actionPointsOrLearnLimit
        learnLimit = learnLimitOrNil
    else
        skillId = skillGroupOrSkillId
        actionPoints = skillIdOrActionPoints
        learnLimit = actionPointsOrLearnLimit
    end
    skillId = resolveSkillId(skillId)
    require("server.learn").learn(user, skillId, actionPoints, learnLimit)
end

Character.SeleneMethods.getSkillValue = function(user, skillId)
     skillId = resolveSkillId(skillId)
     return {
         major = user:getSkill(skillId),
         minor = user:getMinorSkill(skillId)
     }
end
