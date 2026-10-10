local Event = require("selene.event")

local m = {}

m.onLookAtNpc = Event.of("illarion-script-loader:look_at_npc")
m.onUseNpc = Event.of("illarion-script-loader:use_npc")
m.onTalkToNpc = Event.of("illarion-script-loader:talk_to_npc")
m.onNpcCycle = Event.of("illarion-script-loader:npc_cycle")
m.onWeatherChanged = Event.of("illarion-script-loader:weather_changed")
m.onCharacterSelected = Event.of("illarion-script-loader:character_selected")

return m
