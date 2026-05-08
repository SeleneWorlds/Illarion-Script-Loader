local Network = require("selene.network")
local Config = require("selene.config")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

Character.SeleneMethods.talk = function(user, mode, message, messageEnglish)
    local userEntity = user.SeleneEntity
    if messageEnglish == nil then
        local illaPlayerTalkOk, illaPlayerTalk = pcall(require, "server.playertalk")
        if illaPlayerTalkOk then
            local lastAction = userEntity:getRuntimeData(DataKeys.LastAction)
            lastAction[DataFields.LastActionScript] = illaPlayerTalk
            lastAction[DataFields.LastActionFunction] = illaPlayerTalk.talk
            lastAction[DataFields.LastActionArgs] = { user, mode, message }
            message = illaPlayerTalk.talk(user, mode, message)
        end
    end

    local range = 0
    local zRange = 2
    if mode == Character.say then
        range = 14
    elseif mode == Character.whisper then
        range = 2
        zRange = 0
    elseif mode == Character.yell then
        range = 30
    end
    local dimension = user.SeleneEntity:getDimension()
    local entities = dimension:getEntitiesInRange(userEntity:getCoordinate(), range)
    local nonPlayerListeners = {}
    for _, entity in ipairs(entities) do
        local diffZ = math.abs(userEntity:getCoordinate():getZ() - entity:getCoordinate():getZ())
        if diffZ <= zRange then
            local charData = entity:getRuntimeData(DataKeys.Character)
            local characterType = charData[DataFields.CharacterType]
            if characterType == Character.player then
                local effectiveMessage = message
                if messageEnglish and user:getPlayerLanguage() == Player.english then
                    effectiveMessage = messageEnglish
                end
                local showInChat = true
                if stringx.endsWith(effectiveMessage, "#npc") then
                    effectiveMessage = stringx.removeSuffix(effectiveMessage, "#npc")
                    showInChat = false
                end
                Network.sendToEntity(entity, "illarion:chat", {
                    author = userEntity.NetworkId,
                    authorName = user.name,
                    mode = mode,
                    message = effectiveMessage,
                    showInChat = showInChat
                })
            elseif characterType == Character.npc or characterType == Character.monster then
                table.insert(nonPlayerListeners, entity)
            end
        end
    end
    if user:getType() == Character.player then
        for _, entity in ipairs(nonPlayerListeners) do
            local charData = entity:getRuntimeData(DataKeys.Character)
            local characterType = charData[DataFields.CharacterType]
            if characterType == Character.monster then
                local scriptName = charData[DataFields.Script]
                if scriptName then
                    local status, script = pcall(require, scriptName)
                    if status and type(script.receiveText) == "function" then
                        local illaMonster = Character.fromSeleneEntity(entity)
                        if Config.getProperty("useLegacyReceiveText") == "true" then
                            thisNPC = illaMonster
                            script.receiveText(mode, messageEnglish or message, user)
                        else
                            script.receiveText(illaMonster, mode, messageEnglish or message, user)
                        end
                    end
                end
            elseif characterType == Character.npc then
                local scriptName = charData[DataFields.Script]
                if scriptName then
                    local status, script = pcall(require, scriptName)
                    if status and type(script.receiveText) == "function" then
                        local illaNpc = Character.fromSeleneEntity(entity)
                        if Config.getProperty("useLegacyReceiveText") == "true" then
                            thisNPC = illaNpc
                            script.receiveText(mode, messageEnglish or message, user)
                        else
                            script.receiveText(illaNpc, mode, messageEnglish or message, user)
                        end
                    end
                end
            end
        end
    end
    local charData = userEntity:getRuntimeData(DataKeys.Character)
    charData[DataFields.LastSpokenText] = message
end

Character.SeleneMethods.talkLanguage = function(user, mode, language, message)
    local userEntity = user.SeleneEntity
    local range = 0
    local zRange = 2
    if mode == Character.say then
        range = 14
    elseif mode == Character.whisper then
        range = 2
        zRange = 0
    elseif mode == Character.yell then
        range = 30
    end
    local dimension = user.SeleneEntity:getDimension()
    local entities = dimension:getEntitiesInRange(userEntity:getCoordinate(), range)
    local nonPlayerListeners = {}
    for _, entity in ipairs(entities) do
        local diffZ = math.abs(userEntity:getCoordinate():getZ() - entity:getCoordinate():getZ())
        if diffZ <= zRange then
            local charData = entity:getRuntimeData(DataKeys.Character)
            local characterType = charData[DataFields.CharacterType]
            if characterType == Character.player and user:getPlayerLanguage() == language then
                local showInChat = true
                local effectiveMessage = message
                if stringx.endsWith(effectiveMessage, "#npc") then
                    effectiveMessage = stringx.removeSuffix(effectiveMessage, "#npc")
                    showInChat = false
                end
                Network.sendToEntity(entity, "illarion:chat", {
                    author = userEntity.NetworkId,
                    authorName = user.name,
                    mode = mode,
                    message = effectiveMessage,
                    showInChat = showInChat
                })
            elseif characterType == Character.npc or characterType == Character.monster then
                table.insert(nonPlayerListeners, entity)
            end
        end
    end
end

Character.SeleneGetters.activeLanguage = function(user)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    return charData[DataFields.Language] or 0
end

Character.SeleneSetters.activeLanguage = function(user, language)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    charData[DataFields.Language] = language
end

Character.SeleneGetters.lastSpokenText = function(user)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    return charData[DataFields.LastSpokenText] or ""
end
