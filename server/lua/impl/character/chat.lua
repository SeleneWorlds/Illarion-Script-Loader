local Network = require("selene.network")
local Config = require("selene.config")
local NameManager = require("illarion-script-loader.server.lua.lib.nameManager")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ChatMode = require("illarion-script-loader.server.lua.lib.chatMode")
local Events = require("illarion-script-loader.server.lua.lib.events")
local EventLog = require("illarion-script-loader.server.lua.lib.eventLog")

local RaceLanguage = require("illarion-script-loader.server.lua.lib.raceLanguage")

local function talk(user, mode, message, messageEnglish, locale)
    local userEntity = user.SeleneEntity
    mode, message = ChatMode.parsePrefix(mode, message)
    if messageEnglish then
        local englishMode
        englishMode, messageEnglish = ChatMode.parsePrefix(mode, messageEnglish)
        mode = englishMode
    end
    if messageEnglish == nil and locale == nil then
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
    if mode == Character.say or mode == "ooc" or mode == "emote" then
        range = 14
    elseif mode == Character.whisper then
        range = 2
        zRange = 0
    elseif mode == Character.yell then
        range = 30
    end
    local dimension = user.SeleneEntity:getDimension()
    if not dimension then
        return
    end
    local raceLanguage = user.activeLanguage
    local isSpeech = mode ~= "emote" and mode ~= "ooc"
    local prefix = isSpeech and RaceLanguage.prefix(raceLanguage) or ""
    local function stripNpc(text)
        if stringx.endsWith(text, "#npc") then
            return stringx.removeSuffix(text, "#npc"), false
        end
        return text, true
    end
    local original, showGerman = stripNpc(message)
    local originalEnglish, showEnglish
    if messageEnglish then
        originalEnglish, showEnglish = stripNpc(messageEnglish)
    end
    local spoken, spokenEnglish = original, originalEnglish
    if isSpeech then
        local skill = RaceLanguage.skill(user, raceLanguage)
        spoken = RaceLanguage.alter(original, skill)
        if originalEnglish then
            spokenEnglish = RaceLanguage.alter(originalEnglish, skill)
        end
    end
    EventLog.logChat(user, mode, message, messageEnglish, locale)
    local entities = dimension:getEntitiesInRange(userEntity:getCoordinate(), range)
    local nonPlayerListeners = {}
    for _, entity in ipairs(entities) do
        local diffZ = math.abs(userEntity:getCoordinate():getZ() - entity:getCoordinate():getZ())
        if diffZ <= zRange then
            local charData = entity:getRuntimeData(DataKeys.Character)
            local characterType = charData[DataFields.CharacterType]
            if characterType == Character.player then
                local listener = Character.fromSeleneEntity(entity)
                if locale == nil or listener:getPlayerLanguage() == locale then
                    local english = originalEnglish ~= nil and listener:getPlayerLanguage() == Player.english
                    local effectiveMessage = english and originalEnglish or original
                    local showInChat = showGerman
                    if english then
                        showInChat = showEnglish
                    end
                    if isSpeech and entity ~= userEntity then
                        effectiveMessage = RaceLanguage.alter(english and spokenEnglish or spoken,
                            RaceLanguage.skill(listener, raceLanguage))
                    end
                    effectiveMessage = prefix .. effectiveMessage
                    Network.sendToEntity(entity, "illarion:chat", {
                        author = userEntity:getNetworkId(),
                        authorName = NameManager.Get(userEntity, entity),
                        mode = mode,
                        message = effectiveMessage,
                        showInChat = showInChat
                    })
                end
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
                if scriptName and scriptName ~= "" then
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
                local npcMessage = originalEnglish or original
                if isSpeech then
                    npcMessage = prefix .. RaceLanguage.alter(spokenEnglish or spoken,
                        RaceLanguage.skill(Character.fromSeleneEntity(entity), raceLanguage))
                end
                local event = { cancel = false }
                Events.onTalkToNpc:fire(event, entity, user.SelenePlayer, mode, npcMessage)
                if not event.cancel then
                    local scriptName = charData[DataFields.Script]
                    if scriptName and scriptName ~= "" then
                        local status, script = pcall(require, scriptName)
                        if status and type(script.receiveText) == "function" then
                            local illaNpc = Character.fromSeleneEntity(entity)
                            if Config.getProperty("useLegacyReceiveText") == "true" then
                                thisNPC = illaNpc
                                script.receiveText(mode, npcMessage, user)
                            else
                                script.receiveText(illaNpc, mode, npcMessage, user)
                            end
                        end
                    end
                end
            end
        end
    end
    local charData = userEntity:getRuntimeData(DataKeys.Character)
    charData[DataFields.LastSpokenText] = message
end

Character.SeleneMethods.talk = function(user, mode, message, messageEnglish)
    return talk(user, mode, message, messageEnglish)
end

Character.SeleneMethods.talkLanguage = function(user, mode, language, message)
    language = assert(tonumber(language), "language must be a number, was " .. tostring(language))
    return talk(user, mode, message, nil, language)
end

Character.SeleneGetters.activeLanguage = function(user)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    return charData[DataFields.Language] or 0
end

Character.SeleneSetters.activeLanguage = function(user, language)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    charData[DataFields.Language] = assert(RaceLanguage.resolve(language), "Unknown race language: " .. tostring(language))
end

Character.SeleneGetters.lastSpokenText = function(user)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    return charData[DataFields.LastSpokenText] or ""
end
