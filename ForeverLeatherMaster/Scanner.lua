local ADDON, FLM = ...

local scanning = false
local processIndex = 0
local totalAuctions = 0
local processed = 0
local validOffers = 0
local scannerFrame = CreateFrame("Frame")

local function FinishScan()
    scanning = false
    local prices, itemCount, offerCount = FLM:FinalizeAuctionPrices()
    FLM.DB.prices = prices
    FLM.DB.lastScan = time()
    FLM.DB.lastScanCount = processed
    FLM:Print(string.format(
        "Scan terminé : %d annonces examinées, %d offres valides, %d objets. Prix de référence = groupe de prix le plus bas suffisamment représenté.",
        processed, offerCount or validOffers, itemCount
    ))
    FLM:Refresh()
end

local function ProcessBatch()
    if not scanning then return end

    local limit = math.min(processIndex + 249, totalAuctions - 1)
    while processIndex <= limit do
        local name, texture, count, quality, usable, level, levelType,
            minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
            bidderFullName, owner, ownerFullName, saleStatus, itemID =
            C_AuctionHouse.GetReplicateItemInfo(processIndex)

        if itemID and buyoutPrice and buyoutPrice > 0 then
            if FLM:RecordAuctionPrice(itemID, buyoutPrice, count) then
                validOffers = validOffers + 1
            end
        end

        processed = processed + 1
        processIndex = processIndex + 1
    end

    if processIndex >= totalAuctions then
        FinishScan()
    end
end

scannerFrame:SetScript("OnUpdate", function()
    if scanning then ProcessBatch() end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
eventFrame:SetScript("OnEvent", function()
    if not FLM.waitingForReplication then return end
    FLM.waitingForReplication = false

    if not C_AuctionHouse or not C_AuctionHouse.GetNumReplicateItems then
        FLM:Print("API de réplication HDV indisponible.")
        return
    end

    totalAuctions = C_AuctionHouse.GetNumReplicateItems() or 0
    processIndex, processed, validOffers = 0, 0, 0
    FLM.scanObservations = {}
    scanning = true

    if totalAuctions == 0 then
        FinishScan()
    else
        FLM:Print("Données reçues : analyse de " .. totalAuctions .. " annonces...")
    end
end)

function FLM:StartAuctionScan()
    if not C_AuctionHouse or not C_AuctionHouse.ReplicateItems then
        self:Print("API de scan HDV indisponible.")
        return false
    end

    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
        self:Print("Ouvre l'hôtel des ventes avant de lancer le scan.")
        return false
    end

    if self.waitingForReplication or scanning then
        self:Print("Un scan est déjà en cours.")
        return false
    end

    local now = time()
    local elapsed = now - (tonumber(self.DB.lastScan) or 0)
    local cooldown = 15 * 60
    if self.DB.lastScan > 0 and elapsed < cooldown then
        local remaining = cooldown - elapsed
        self:Print(string.format("Délai serveur estimé : encore %d min %d s avant un nouveau scan complet.",
            math.floor(remaining / 60), remaining % 60))
        return false
    end

    self.waitingForReplication = true
    local ok, err = pcall(C_AuctionHouse.ReplicateItems)
    if not ok then
        self.waitingForReplication = false
        self:Print("Le serveur a refusé le scan : " .. tostring(err))
        return false
    end

    self:Print("Demande de scan complet envoyée. Le serveur peut imposer un délai de 15 minutes.")
    return true
end

-- Capture les résultats des recherches normales de l'hôtel des ventes.
-- Ces événements se déclenchent aussi lorsque le joueur consulte un objet.
local function CaptureItemSearch(itemKey)
    if not itemKey or not itemKey.itemID or not C_AuctionHouse then return end
    local itemID = tonumber(itemKey.itemID)
    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    local prices = {}
    for i = 1, count do
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if info and info.buyoutAmount and info.buyoutAmount > 0 then
            local quantity = math.max(1, tonumber(info.quantity) or 1)
            prices[#prices + 1] = math.floor(info.buyoutAmount / quantity)
        end
    end
    if #prices > 0 then FLM:UpdatePriceFromListings(itemID, prices) end
end

local function CaptureCommoditySearch(itemID)
    itemID = tonumber(itemID)
    if not itemID or not C_AuctionHouse then return end
    local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    local prices = {}
    for i = 1, count do
        local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if info and info.unitPrice and info.unitPrice > 0 then
            prices[#prices + 1] = info.unitPrice
        end
    end
    if #prices > 0 then FLM:UpdatePriceFromListings(itemID, prices) end
end

-- On ne met à jour le prix de référence qu'avec les résultats détaillés
-- d'une recherche par objet ou par matière première. Les résumés de navigation
-- ne fournissent souvent que le prix minimum et peuvent être une annonce isolée.
local searchFrame = CreateFrame("Frame")
searchFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
searchFrame:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
searchFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
searchFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED")
searchFrame:SetScript("OnEvent", function(_, event, payload)
    if event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
        CaptureItemSearch(payload)
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED" then
        CaptureCommoditySearch(payload)
    end
end)
