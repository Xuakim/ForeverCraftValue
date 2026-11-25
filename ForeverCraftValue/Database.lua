local ADDON, FLM = ...

-- Le prix de référence est le prix unitaire le plus bas observé.
local function GetMarketPrice(values)
    table.sort(values)
    local count = #values
    if count == 0 then return nil end
    return values[1], 1, count
end

-- Met à jour le prix d'un objet à partir des annonces réellement consultées.
function FLM:UpdatePriceFromListings(itemID, unitPrices)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or type(unitPrices) ~= "table" or #unitPrices < 1 then
        return false
    end

    local valid = {}
    for _, price in ipairs(unitPrices) do
        price = tonumber(price)
        if price and price > 0 then valid[#valid + 1] = math.floor(price) end
    end
    if #valid < 1 then return false end

    local reference = GetMarketPrice(valid)
    if not reference or reference <= 0 then return false end

    self.DB.prices = self.DB.prices or {}
    self.DB.priceUpdated = self.DB.priceUpdated or {}
    self.DB.prices[itemID] = reference
    self.DB.priceUpdated[itemID] = time()
    self:Refresh()
    return true
end
