local Network = require("selene.network")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local Validation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local Books = {}
local nextId = 0

local function sendPage(user, session, page)
    if page < 1 or page > session.pageCount then return end
    local content = session.read(page)
    if not content then return end
    Network.sendToPlayer(user.SelenePlayer, "illarion:book_page", {
        id = session.id,
        page = page,
        pageCount = session.pageCount,
        itemId = content.itemId or 0,
        text = content.text or ""
    })
end

-- A reader is authorized by the script that opens the book. Page requests never
-- replay item use, execute arbitrary scripts, or accept a client-selected book ID.
function Books.open(user, pageCount, read, page)
    if not user.SelenePlayer or not user.SeleneEntity then return end
    pageCount = Validation.integer(pageCount, 1)
    if not pageCount then return end
    page = math.min(Validation.integer(page, 1) or 1, pageCount)
    nextId = nextId + 1
    local session = { id = nextId, pageCount = pageCount, read = read }
    local state = user.SeleneEntity:getRuntimeData(DataKeys.Book)
    state.session = session
    sendPage(user, session, page)
end

function Books.show(user, text, itemId)
    Books.open(user, 1, function()
        return { text = text, itemId = itemId or 0 }
    end)
end

Network.handlePayload("illarion:book_request_page", function(player, payload)
    local id = Validation.integer(payload.id, 1)
    local page = Validation.integer(payload.page, 1)
    local entity = player:getControlledEntity()
    if not id or not page or not entity then return end
    local session = entity:getRuntimeData(DataKeys.Book).session
    if not session or session.id ~= id then return end
    sendPage(Character.fromSelenePlayer(player), session, page)
end)

Network.handlePayload("illarion:book_close", function(player, payload)
    local id = Validation.integer(payload.id, 1)
    local entity = player:getControlledEntity()
    if not id or not entity then return end
    local state = entity:getRuntimeData(DataKeys.Book)
    if state.session and state.session.id == id then
        state.session = nil
    end
end)

return Books
