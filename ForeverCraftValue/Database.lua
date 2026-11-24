local ADDON, FLM = ...

-- Collecte les prix unitaires de toutes les annonces d'un objet.
function FLM:RecordAuctionPrice(itemID, totalBuyout, stackCount)
    itemID = tonumber(itemID)
    totalBuyout = tonumber(totalBuyout)
    stackCount = math.max(1, tonumber(stackCount) or 1)

    if not itemID or itemID <= 0 or not totalBuyout or totalBuyout <= 0 then
        return false
    end

    local unitPrice = math.floor(totalBuyout / stackCount)
    if unitPrice <= 0 then return false end

    self.scanObservations = self.scanObservations or {}
    local offers = self.scanObservations[itemID]
    if not offers then
        offers = {}
        self.scanObservations[itemID] = offers
    end

    offers[#offers + 1] = unitPrice
    return true
end

-- Le prix de référence est le prix unitaire le plus bas observé.
local function GetMarketPrice(values)
    table.sort(values)
    local count = #values
    if count == 0 then return nil end
    return values[1], 1, count
end

function FLM:FinalizeAuctionPrices()
    -- Un scan partiel ne doit jamais effacer les prix déjà connus.
    local prices = self.DB.prices or {}
    self.DB.priceUpdated = self.DB.priceUpdated or {}
    local observations = self.scanObservations or {}
    local itemCount, offerCount, updatedAt = 0, 0, time()

    for itemID, offers in pairs(observations) do
        local reference = GetMarketPrice(offers)
        if reference and reference > 0 then
            prices[itemID] = reference
            self.DB.priceUpdated[itemID] = updatedAt
            itemCount = itemCount + 1
            offerCount = offerCount + #offers
        end
    end

    self.scanObservations = nil
    return prices, itemCount, offerCount
end

-- Met à jour le prix d'un objet à partir des annonces réellement consultées.
function FLM:UpdatePriceFromListings(itemID, unitPrices)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or type(unitPrices) ~= "table" or #unitPrices < 2 then
        return false
    end

    local valid = {}
    for _, price in ipairs(unitPrices) do
        price = tonumber(price)
        if price and price > 0 then valid[#valid + 1] = math.floor(price) end
    end
    if #valid < 2 then return false end

    local reference = GetMarketPrice(valid)
    if not reference or reference <= 0 then return false end

    self.DB.prices = self.DB.prices or {}
    self.DB.priceUpdated = self.DB.priceUpdated or {}
    self.DB.prices[itemID] = reference
    self.DB.priceUpdated[itemID] = time()
    self:Refresh()
    return true
end
