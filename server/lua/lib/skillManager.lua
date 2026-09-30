local Attributes = require("selene.attributes")
local Network = require("selene.network")
local Registries = require("selene.registries")

local m = {}

local function skillPayload(user, skillId)
    local skill = Registries.findByMetadata("illarion:skills", "id", skillId)
    if not skill then
        return nil
    end

    local group = skill:getField("group") or ""
    local groupId = tonumber(group:match("skill_group_(%d+)$")) or 0
    return {
        id = skillId,
        name = skill:getMetadata("name") or "skill_" .. skillId,
        group = groupId,
        major = m.GetMajorSkillAttribute(user, skillId):getEffectiveValue(),
        minor = m.GetMinorSkillAttribute(user, skillId):getEffectiveValue()
    }
end

local function sendSkill(user, skillId)
    local payload = skillPayload(user, skillId)
    if payload then
        Network.sendToEntity(user.SeleneEntity, "illarion:skill", payload)
    end
end

function m.GetMajorSkillAttribute(user, skillId)
    local attributeKey = "illarion:majorSkills:" .. skillId
    local attribute = user.SeleneEntity:getAttribute(attributeKey)
    if attribute == nil then
        attribute = user.SeleneEntity:createAttribute(attributeKey, 0)
        attribute:addConstraint("clamp", Attributes.clampFilter(0, 100))
        attribute:subscribe(function()
            sendSkill(user, skillId)
        end)
    end
    return attribute
end

function m.GetMinorSkillAttribute(user, skillId)
    local attributeKey = "illarion:minorSkills:" .. skillId
    local attribute = user.SeleneEntity:getAttribute(attributeKey)
    if attribute == nil then
        attribute = user.SeleneEntity:createAttribute(attributeKey, 0)
        attribute:addConstraint("clamp", Attributes.clampFilter(0, 10000))
        attribute:subscribe(function()
            sendSkill(user, skillId)
        end)
    end
    return attribute
end

function m.SendAll(user)
    local skills = {}
    for _, skill in pairs(Registries.findAll("illarion:skills")) do
        local skillId = tonumber(skill:getMetadata("id"))
        if skillId then
            local payload = skillPayload(user, skillId)
            if payload.major > 0 or payload.minor > 0 then
                table.insert(skills, payload)
            end
        end
    end
    Network.sendToEntity(user.SeleneEntity, "illarion:skills", { skills = skills })
end

return m
