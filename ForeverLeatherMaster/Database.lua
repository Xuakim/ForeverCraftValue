local ADDON, FLM = ...

-- Collecte toutes les offres d'un objet pendant le scan.
-- Le prix final est calculé à partir de la médiane, pas du minimum isolé.
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

local function MedianPrice(values)
    table.sort(values)
    local count = #values
    if count == 0 then return nil end

    -- Rang supérieur en cas de nombre pair : évite qu'une offre très basse
    -- parmi seulement deux annonces tire le prix de référence vers le bas.
    local index = math.floor(count / 2) + 1
    return values[index]
end

function FLM:FinalizeAuctionPrices()
    local prices = {}
    local observations = self.scanObservations or {}
    local itemCount, offerCount = 0, 0

    for itemID, offers in pairs(observations) do
        local reference = MedianPrice(offers)
        if reference and reference > 0 then
            prices[itemID] = reference
            itemCount = itemCount + 1
            offerCount = offerCount + #offers
        end
    end

    self.scanObservations = nil
    return prices, itemCount, offerCount
end
