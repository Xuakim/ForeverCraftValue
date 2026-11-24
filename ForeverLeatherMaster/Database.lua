local ADDON, FLM = ...

function FLM:RecordAuctionPrice(itemID, totalBuyout, stackCount)
    itemID = tonumber(itemID)
    totalBuyout = tonumber(totalBuyout)
    stackCount = math.max(1, tonumber(stackCount) or 1)

    if not itemID or itemID <= 0 or not totalBuyout or totalBuyout <= 0 then
        return false
    end

    local unitPrice = math.floor(totalBuyout / stackCount)
    local target = self.scanPrices or self.DB.prices
    local oldPrice = target[itemID]

    -- Keep the lowest unit buyout seen in the current full snapshot.
    if not oldPrice or unitPrice < oldPrice then
        target[itemID] = unitPrice
    end
    return true
end
