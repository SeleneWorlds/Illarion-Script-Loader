local ChatMode = {}

local PrefixModes = {
    w = Character.whisper,
    s = Character.yell,
    o = "ooc",
    me = "emote"
}

function ChatMode.parsePrefix(mode, message)
    if type(message) ~= "string" then
        return mode, message
    end

    local prefix = string.match(message, "^#(me)%s*") or string.match(message, "^#([wso])%s*")
    if not prefix then
        return mode, message
    end

    return PrefixModes[prefix], string.gsub(message, "^#" .. prefix .. "%s*", "", 1)
end

return ChatMode
