local Network = require("selene.network")

-- Per-player transport budgets, independent of gameplay action costs/cooldowns.
-- Administrators can override any ID using payload_rate_limits in server.properties.
local function defaults(packetsPerSecond, burst, payloadIds)
    for _, payloadId in ipairs(payloadIds) do
        Network.setDefaultPayloadRateLimit("illarion:" .. payloadId, packetsPerSecond, burst)
    end
end

-- Allow a few rapid messages/commands, then one per second.
defaults(1, 5, { "chat" })

-- Character requests can perform database reads; creation also writes persistent data.
-- Bursts allow retries after validation failures without permitting sustained flooding.
defaults(1, 3, { "request_characters", "request_character_creation", "select_character" })
defaults(0.2, 3, { "create_character" })

-- Time/weather are already pushed by the server; requests are for initial sync/resync.
defaults(0.2, 3, { "request_time", "request_weather" })

-- Script actions and container opens are deliberate clicks, with room for quick sequences.
defaults(5, 10, {
    "cast", "use_at", "use_slot", "use_slot_at", "push_character",
    "open_container_at", "open_container_slot"
})

-- Dragging, dropping, targeting, and context menus can arrive in short bursts.
defaults(10, 20, {
    "move_slot_to_slot", "move_coordinate_to_slot", "move_coordinate_to_coordinate",
    "move_slot_to_coordinate", "drop_slot_in_front", "set_combat_target",
    "request_menu_at", "menu_action_at", "look_at", "look_at_entity"
})

-- Hover/focus can cross many inventory/menu items quickly.
defaults(20, 40, { "look_at_slot", "look_at_menu_item", "merchant_dialog:look_at" })

-- Close/abort messages and one-shot dialog replies rely on existing state validation.
-- Leave these unrestricted so cleanup and valid pending replies are not silently lost.
