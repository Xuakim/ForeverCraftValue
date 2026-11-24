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

-- Regroupe les prix proches (écart maximal de 20 % depuis le début du groupe).
-- Un groupe doit représenter au moins 15 % des annonces et au moins 2 offres
-- pour être considéré comme un niveau de prix réellement présent sur le marché.
local function GetMarketPrice(values)
    table.sort(values)
    local count = #values
    if count == 0 then return nil end
    if count == 1 then return values[1] end

    local groups = {}
    local firstPrice, groupCount

    for i = 1, count do
        local price = values[i]
        if not firstPrice or price > firstPrice * 1.20 then
            if firstPrice then
                groups[#groups + 1] = { price = firstPrice, count = groupCount }
            end
            firstPrice, groupCount = price, 1
        else
            groupCount = groupCount + 1
        end
    end
    groups[#groups + 1] = { price = firstPrice, count = groupCount }

    local minimumSupport = math.max(2, math.ceil(count * 0.15))
    for i = 1, #groups do
        if groups[i].count >= minimumSupport then
            return groups[i].price, groups[i].count, count
        end
    end

    -- Échantillon trop dispersé : la médiane haute évite qu'une annonce isolée
    -- au prix plancher fasse artificiellement chuter l'estimation.
    return values[math.floor(count / 2) + 1], 0, count
end

function FLM:FinalizeAuctionPrices()
    local prices = {}
    local observations = self.scanObservations or {}
    local itemCount, offerCount = 0, 0

    for itemID, offers in pairs(observations) do
        local reference = GetMarketPrice(offers)
        if reference and reference > 0 then
            prices[itemID] = reference
            itemCount = itemCount + 1
            offerCount = offerCount + #offers
        end
    end

    self.scanObservations = nil
    return prices, itemCount, offerCount
end
