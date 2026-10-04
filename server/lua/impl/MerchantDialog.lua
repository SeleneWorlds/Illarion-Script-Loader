local Registries = require("selene.registries")

MerchantDialog.SeleneConstructor = function(title, callback)
    return {
        type = "MerchantDialog",
        title = title,
        callback = callback,
        offers = {},
        primaryRequests = {},
        secondaryRequests = {}
    }
end

MerchantDialog.SeleneMethods.addOffer = function(self, itemId, name, price, buyStack)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    price = assert(tonumber(price), "price must be a number, was " .. tostring(price))
    buyStack = assert(tonumber(buyStack), "buyStack must be a number, was " .. tostring(buyStack))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Unknown item id " .. itemId)
    end
    table.insert(self.offers, {
        itemDef = itemDef,
        name = name,
        price = price,
        buyStack = itemDef:getField("buyStack")
    })
end

MerchantDialog.SeleneMethods.addPrimaryRequest = function(self, itemId, name, price)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    price = assert(tonumber(price), "price must be a number, was " .. tostring(price))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Unknown item id " .. itemId)
    end
    table.insert(self.primaryRequests, {
        itemDef = itemDef,
        name = name,
        price = price
    })
end

MerchantDialog.SeleneMethods.addSecondaryRequest = function(self, itemId, name, price)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    price = assert(tonumber(price), "price must be a number, was " .. tostring(price))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Unknown item id " .. itemId)
    end
    table.insert(self.secondaryRequests, {
        itemDef = itemDef,
        name = name,
        price = price
    })
end

MerchantDialog.SeleneMethods.getResult = function(self)
    return self.result
end

MerchantDialog.SeleneMethods.getPurchaseIndex = function(self)
    return self.purchaseIndex
end

MerchantDialog.SeleneMethods.getPurchaseAmount = function(self)
    return self.purchaseAmount
end

MerchantDialog.SeleneMethods.getSaleItem = function(self)
    return self.saleItem
end

MerchantDialog.SeleneMethods.getLookAtList = function(self)
    return self.lookAtList
end
