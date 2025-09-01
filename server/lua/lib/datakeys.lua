local m = {}

m.ID = "illarion:id"
m.CharacterType = "illarion:characterType"
m.Race = "illarion:race"
m.Sex = "illarion:sex"
m.MagicType = "illarion:magicType"
m.MagicFlags = "illarion:magicFlags:"
m.Quest = function(questId) return "illarion:quests:" .. questId end
m.Language = "illarion:language"
m.LastSpokenText = "illarion:lastSpokenText"
m.Effects = "illarion:effects"
m.CurrentLoginTimestamp = "illarion:currentLoginTimestamp"
m.TotalOnlineTime = "illarion:totalOnlineTime"
m.CurrentAction = "illarion:currentAction"
m.LastActionScript = "illarion:lastActionScript"
m.LastActionFunction = "illarion:lastActionFunction"
m.LastActionArgs = "illarion:lastActionArgs"
m.Introduction = function(id) return "illarion:introduction:" .. id end
m.NPC = "illarion:npc"
m.Monster = "illarion:monster"
m.Script = "illarion:script"
m.Dead = "illarion:dead"
m.CombatTarget = "illarion:combatTarget"
m.Weather = "illarion:weather"
m.MonsterSpawn = "illarion:monsterSpawn"
m.Dialog = function(id) return "illarion:dialog:" .. id end

return m