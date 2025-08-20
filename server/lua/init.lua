local Registries = require("selene.registries")

local allRaces = Registries.FindAll("illarion:races")
for _, race in ipairs(allRaces) do
    Character[race:GetMetadata("name")] = race:GetMetadata("id")
end

local allSkills = Registries.FindAll("illarion:skills")
for _, skill in ipairs(allSkills) do
    Character[skill:GetMetadata("name")] = skill:GetMetadata("id")
end

local allItems = Registries.FindAll("illarion:items")
for _, item in ipairs(allItems) do
    local name = item:GetField("name")
    if name then
        Item[name] = item:GetMetadata("id")
    end
end
