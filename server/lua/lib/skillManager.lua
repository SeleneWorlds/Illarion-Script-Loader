local Attributes = require("selene.attributes")
local Network = require("selene.network")

local m = {}

function m.GetMajorSkillAttribute(user, skillId)
    local attributeKey = "illarion:majorSkills:" .. skillId
    local attribute = user.SeleneEntity:getAttribute(attributeKey)
    if attribute == nil then
        attribute = user.SeleneEntity:createAttribute(attributeKey, 0)
        attribute:addConstraint("clamp", Attributes.clampFilter(0, 100))
    end
    return attribute
end

function m.GetMinorSkillAttribute(user, skillId)
    local attributeKey = "illarion:minorSkills:" .. skillId
    local attribute = user.SeleneEntity:getAttribute(attributeKey)
    if attribute == nil then
        attribute = user.SeleneEntity:createAttribute(attributeKey, 0)
        attribute:addConstraint("clamp", Attributes.clampFilter(0, 10000))
    end
    return attribute
end

return m