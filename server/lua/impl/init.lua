local Registries = require("selene.registries")

local allRaces = Registries.findAll("illarion:races")
for _, race in pairs(allRaces) do
    local raceName = race:getMetadata("name") or "race_" .. race:getMetadata("id")
    Character[raceName] = race:getMetadata("id")
end

local allSkills = Registries.findAll("illarion:skills")
for _, skill in pairs(allSkills) do
    Character[skill:getMetadata("name")] = skill:getMetadata("id")
end

local allItems = Registries.findAll("illarion:items")
for _, item in pairs(allItems) do
    local name = item:getField("name")
    if name then
        Item[name] = item:getMetadata("id")
    end
end
