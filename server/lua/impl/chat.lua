local Players = require("selene.players")
local Network = require("selene.network")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaPlayerTalk = require("server.playertalk")

Character.SeleneMethods.talk = function(user, mode, message, messageEnglish)
    if messageEnglish == nil then
        entity.CustomData[DataKeys.LastActionScript] = illaPlayerTalk
        entity.CustomData[DataKeys.LastActionFunction] = illaPlayerTalk.talk
        entity.CustomData[DataKeys.LastActionArgs] = { user, mode, message }
        message = illaPlayerTalk.talk(user, mode, message)
    end

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
    local dimension = user.SeleneEntity.Dimension
    local entities = dimension:GetEntitiesInRange(userEntity.Coordinate, range)
    for _, entity in ipairs(entities) do
        if userEntity.ZCoordinate < entity.ZCoordinate + zRange and userEntity.ZCoordinate > entity.ZCoordinate - zRange then
            local characterType = entity.CustomData[DataKeys.CharacterType]
            if characterType == Character.player then
                local effectiveMessage = message
                if messageEnglish and user:getPlayerLanguage() == Player.english then
                    effectiveMessage = messageEnglish
                end
                Network.SendToPlayer(player, "illarion:chat", {
                    author = userEntity.NetworkId,
                    authorName = user.name,
                    mode = mode,
                    message = effectiveMessage
                })
            elseif characterType == Character.monster then
                local monster = entity.CustomData[DataKeys.Monster]
                local scriptName = monster:GetField("script")
                if scriptName then
                    local status, script = pcall(require, scriptName)
                    if status and type(script.receiveText) == "function" then
                        local illaMonster = Character.fromSeleneEntity(entity)
                        script.receiveText(illaMonster, mode, messageEnglish or message, user)
                    end
                end
            elseif characterType == Character.npc then
                local npc = entity.CustomData[DataKeys.Npc]
                local scriptName = npc:GetField("script")
                if scriptName then
                    local status, script = pcall(require, scriptName)
                    if status and type(script.receiveText) == "function" then
                        local illaNpc = Character.fromSeleneEntity(entity)
                        script.receiveText(illaNpc, mode, messageEnglish or message, user)
                    end
                end
            end
        end
    end
    entity.CustomData[DataKeys.LastSpokenText] = message
end

Character.SeleneGetters.activeLanguage = function(user)
    local entity = user.SeleneEntity
    return entity.CustomData[DataKeys.Language] or 0
end

Character.SeleneSetters.activeLanguage = function(user, language)
    entity.CustomData[DataKeys.Language] = language
end

Character.SeleneGetters.lastSpokenText = function(user)
    return entity.CustomData[DataKeys.LastSpokenText] or ""
end

world.broadcast = function(world, messageDe, messageEn)
    local players = Players.GetOnlinePlayers()
    for _,player in ipairs(players) do
        if user.SelenePlayer.Language == "de" then
            Network.SendToPlayer(user.SelenePlayer, "illarion:inform", { Message = messageDe })
        else
            Network.SendToPlayer(user.SelenePlayer, "illarion:inform", { Message = messageEn })
        end
    end
end

Network.HandlePayload("illarion:chat", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    character:talk(payload.mode, payload.message)
end)