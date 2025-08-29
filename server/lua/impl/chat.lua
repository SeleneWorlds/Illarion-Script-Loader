local Players = require("selene.players")
local Network = require("selene.network")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local illaPlayerTalk = require("server.playertalk")

Character.SeleneMethods.talk = function(user, mode, message, messageEnglish)
    local userEntity = user.SeleneEntity
    if messageEnglish == nil then
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
    for _, entity in ipairs(entities) do
        local diffZ = math.abs(userEntity.Coordinate.Z - entity.Coordinate.Z)
        if diffZ <= zRange then
            local characterType = entity.CustomData[DataKeys.CharacterType]
            if characterType == Character.player then
                local effectiveMessage = message
                if messageEnglish and user:getPlayerLanguage() == Player.english then
                    effectiveMessage = messageEnglish
                end
                Network.SendToEntity(entity, "illarion:chat", {
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
                local npc = entity.CustomData[DataKeys.NPC]
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
    local mode = Character.say
    if payload.mode == "whisper" then
        mode = Character.whisper
    elseif payload.mode == "yell" then
        mode = Character.yell
    end
    character:talk(mode, payload.message)
end)