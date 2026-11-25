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
    self.DB.priceHistory = self.DB.priceHistory or {}

    local now = time()
    local previous = tonumber(self.DB.prices[itemID])
    local history = self.DB.priceHistory[itemID]
    if type(history) ~= "table" then
        history = {}
        self.DB.priceHistory[itemID] = history
    end

    -- Un point au premier relevé ou si le prix varie d'au moins 1 %.
    local addPoint = #history == 0 or not previous or previous <= 0
    if not addPoint then
        addPoint = math.abs(reference - previous) / previous >= 0.01
    end
    if addPoint then
        history[#history + 1] = { time = now, price = reference }
    end

    -- Conservation de 90 jours maximum et de 200 points par objet.
    local cutoff = now - (90 * 24 * 60 * 60)
    local kept = {}
    for _, point in ipairs(history) do
        local stamp, price = tonumber(point.time), tonumber(point.price)
        if stamp and stamp >= cutoff and price and price > 0 then
            kept[#kept + 1] = { time = stamp, price = math.floor(price) }
        end
    end
    while #kept > 200 do table.remove(kept, 1) end
    self.DB.priceHistory[itemID] = kept

    self.DB.prices[itemID] = reference
    self.DB.priceUpdated[itemID] = now
    self:Refresh()
    return true
end
