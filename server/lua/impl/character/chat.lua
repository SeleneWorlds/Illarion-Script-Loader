local Network = require("selene.network")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.talk = function(user, mode, message, messageEnglish)
    local userEntity = user.SeleneEntity
    if messageEnglish == nil then
        local illaPlayerTalk = require("server.playertalk")
        userEntity.CustomData[DataKeys.LastActionScript] = illaPlayerTalk
        userEntity.CustomData[DataKeys.LastActionFunction] = illaPlayerTalk.talk
        userEntity.CustomData[DataKeys.LastActionArgs] = { user, mode, message }
        message = illaPlayerTalk.talk(user, mode, message)
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
    local dimension = user.SeleneEntity.Dimension
    local entities = dimension:GetEntitiesInRange(userEntity.Coordinate, range)
    local nonPlayerListeners = {}
    for _, entity in ipairs(entities) do
        local diffZ = math.abs(userEntity.Coordinate.Z - entity.Coordinate.Z)
        if diffZ <= zRange then
            local characterType = entity.CustomData[DataKeys.CharacterType]
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
                Network.SendToEntity(entity, "illarion:chat", {
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
    for _, entity in ipairs(nonPlayerListeners) do
        local characterType = entity.CustomData[DataKeys.CharacterType]
        if characterType == Character.monster then
            local scriptName = entity.CustomData[DataKeys.Script]
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.receiveText) == "function" then
                    local illaMonster = Character.fromSeleneEntity(entity)
                    script.receiveText(illaMonster, mode, messageEnglish or message, user)
                end
            end
        elseif characterType == Character.npc then
            local scriptName = entity.CustomData[DataKeys.Script]
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.receiveText) == "function" then
                    local illaNpc = Character.fromSeleneEntity(entity)
                    script.receiveText(illaNpc, mode, messageEnglish or message, user)
                end
            end
        end
    end
    userEntity.CustomData[DataKeys.LastSpokenText] = message
end

Character.SeleneGetters.activeLanguage = function(user)
    return user.SeleneEntity.CustomData[DataKeys.Language] or 0
end

Character.SeleneSetters.activeLanguage = function(user, language)
    user.SeleneEntity.CustomData[DataKeys.Language] = language
end

Character.SeleneGetters.lastSpokenText = function(user)
    return user.SeleneEntity.CustomData[DataKeys.LastSpokenText] or ""
end