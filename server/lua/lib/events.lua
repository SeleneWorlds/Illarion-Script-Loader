local Event = require("selene.event")

local m = {}

m.onLookAtNpc = Event.of("illarion-script-loader:look_at_npc")
m.onUseNpc = Event.of("illarion-script-loader:use_npc")

return m
