local RaceLanguage = {}

local names = {
    [0] = "common", "human", "dwarf", "elf", "lizard", "orc",
    "halfling", "fairy", "gnome", "goblin", "ancient"
}
local prefixes = {
    [0] = "", "[hum] ", "[dwa] ", "[elf] ", "[liz] ", "[orc] ",
    "[hal] ", "[fai] ", "[gno] ", "[gob] ", "[anc] "
}

function RaceLanguage.resolve(value)
    if type(value) == "string" then
        value = value:lower():gsub("^%s+", ""):gsub("%s+$", "")
        value = value:gsub("%s+language$", "")
    end
    local id = tonumber(value)
    if id and names[id] then
        return id
    end
    for languageId, name in pairs(names) do
        if value == name then
            return languageId
        end
    end
end

function RaceLanguage.prefix(language)
    return prefixes[language] or ""
end

function RaceLanguage.skill(character, language)
    return character:getSkill((names[language] or names[0]) .. " language")
end

function RaceLanguage.alter(message, skill)
    if skill >= 70 then
        return message
    end
    return (message:gsub("[%z\1-\127\194-\244][\128-\191]*", function(character)
        if math.random(0, 70) > skill then
            return "*"
        end
        return character
    end))
end

return RaceLanguage
