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

local function GetReasonableLowPrice(values)
    table.sort(values)
    local count = #values
    if count == 0 then return nil end
    if count == 1 then return values[1] end

    -- Médiane comme référence robuste, puis on écarte les annonces
    -- inférieures à 70 % de cette référence. Parmi les autres,
    -- on retient le prix le plus bas pour rester compétitif.
    local median = values[math.floor((count + 1) / 2)]
    local floorThreshold = median * 0.70

    for i = 1, count do
        if values[i] >= floorThreshold then
            return values[i]
        end
    end

    return median
end

function FLM:FinalizeAuctionPrices()
    local prices = {}
    local observations = self.scanObservations or {}
    local itemCount, offerCount = 0, 0

    for itemID, offers in pairs(observations) do
        local reference = GetReasonableLowPrice(offers)
        if reference and reference > 0 then
            prices[itemID] = reference
            itemCount = itemCount + 1
            offerCount = offerCount + #offers
        end
    end

    self.scanObservations = nil
    return prices, itemCount, offerCount
end
