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

-- Regroupe les annonces dont les prix sont proches (écart maximal de 20 %).
-- Retient le groupe le plus représenté, puis sa médiane : une annonce isolée
-- très basse ne peut ainsi pas fixer le prix de référence.
local function GetMarketPrice(values)
    table.sort(values)
    local count = #values
    if count == 0 then return nil end
    if count == 1 then return values[1], 1, 1 end

    local groups = {}
    local startIndex, firstPrice

    for i = 1, count do
        local price = values[i]
        if not firstPrice or price > firstPrice * 1.20 then
            if firstPrice then
                groups[#groups + 1] = { first = startIndex, last = i - 1, count = i - startIndex }
            end
            startIndex, firstPrice = i, price
        end
    end
    groups[#groups + 1] = { first = startIndex, last = count, count = count - startIndex + 1 }

    local best = nil
    for _, group in ipairs(groups) do
        if not best or group.count > best.count then best = group end
    end

    -- Si aucun groupe ne domine réellement, la médiane globale est plus prudente.
    if not best or best.count < math.max(2, math.ceil(count * 0.15)) then
        return values[math.floor((count + 1) / 2)], 0, count
    end

    local middle = math.floor((best.first + best.last) / 2)
    if best.count % 2 == 1 then
        return values[middle], best.count, count
    end
    return math.floor((values[middle] + values[middle + 1]) / 2), best.count, count
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
