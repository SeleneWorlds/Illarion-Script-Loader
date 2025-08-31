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
m.NPCScript = "illarion:npcScript"
m.Monster = "illarion:monster"
m.MonsterScript = "illarion:monsterScript"
m.Dead = "illarion:dead"
m.CombatTarget = "illarion:combatTarget"

return m