local ADDON, FLM = ...

local scanning = false
local processIndex = 0
local totalAuctions = 0
local processed = 0
local validOffers = 0
local scanMode = "targeted"
local scannerFrame = CreateFrame("Frame")

local function FinishScan()
    scanning = false
    local prices, itemCount, offerCount = FLM:FinalizeAuctionPrices()
    FLM.DB.prices = prices
    FLM.DB.lastScan = time()
    FLM.DB.lastScanCount = processed
    FLM.DB.lastScanMode = scanMode
    if scanMode == "full" then
        FLM.DB.lastFullScan = FLM.DB.lastScan
    else
        FLM.DB.lastTargetedScan = FLM.DB.lastScan
    end

    local modeLabel = scanMode == "full" and "complet" or "ciblé"
    FLM:Print(string.format(
        "Scan %s terminé : %d annonces parcourues, %d offres utiles, %d objets actualisés.",
        modeLabel, processed, offerCount or validOffers, itemCount
    ))

    FLM.scanWantedItems = nil
    FLM:Refresh()
end

local function ProcessBatch()
    if not scanning then return end

    -- Limiter le travail par image pour éviter de figer l'interface sur les gros HDV.
    local limit = math.min(processIndex + 99, totalAuctions - 1)
    local startedAt = GetTime and GetTime() or 0
    while processIndex <= limit do
        local name, texture, count, quality, usable, level, levelType,
            minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
            bidderFullName, owner, ownerFullName, saleStatus, itemID =
            C_AuctionHouse.GetReplicateItemInfo(processIndex)

        -- En mode ciblé, les annonces hors chaîne de craft sont ignorées.
        if itemID and buyoutPrice and buyoutPrice > 0
            and (not FLM.scanWantedItems or FLM.scanWantedItems[itemID]) then
            if FLM:RecordAuctionPrice(itemID, buyoutPrice, count) then
                validOffers = validOffers + 1
            end
        end

        processed = processed + 1
        processIndex = processIndex + 1

        -- Budget de traitement d'environ 3 ms par image, avec un plafond de 100 annonces.
        if GetTime and processIndex <= limit and (GetTime() - startedAt) >= 0.003 then
            break
        end
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
        FLM.scanWantedItems = nil
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
        FLM:Print(string.format("Données reçues : filtrage de %d annonces (%s)...",
            totalAuctions, scanMode == "full" and "scan complet" or "scan ciblé"))
    end
end)

function FLM:StartAuctionScan(mode)
    mode = mode or "targeted"
    if mode ~= "targeted" and mode ~= "full" then return false end

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

    local wantedItems
    if mode == "targeted" then
        wantedItems = self:BuildRelevantItemIDs()
        local count = 0
        for _ in pairs(wantedItems or {}) do count = count + 1 end
        if count == 0 then
            self:Print("Aucune ressource à scanner. Importe d'abord les recettes d'un métier.")
            return false
        end
        self.scanWantedItems = wantedItems
    else
        self.scanWantedItems = nil
    end

    local now = time()
    local elapsed = now - (tonumber(self.DB.lastScan) or 0)
    local cooldown = 15 * 60
    if self.DB.lastScan > 0 and elapsed < cooldown then
        local remaining = cooldown - elapsed
        self:Print(string.format("Délai serveur estimé : encore %d min %d s avant une nouvelle réplication HDV.",
            math.floor(remaining / 60), remaining % 60))
        self.scanWantedItems = nil
        return false
    end

    scanMode = mode
    self.waitingForReplication = true
    local ok, err = pcall(C_AuctionHouse.ReplicateItems)
    if not ok then
        self.waitingForReplication = false
        self.scanWantedItems = nil
        self:Print("Le serveur a refusé le scan : " .. tostring(err))
        return false
    end

    if mode == "targeted" then
        local count = 0
        for _ in pairs(wantedItems) do count = count + 1 end
        self:Print(string.format("Scan ciblé demandé : %d objets utiles. Les annonces HDV seront filtrées après réception.", count))
    else
        self:Print("Scan complet demandé : toutes les annonces seront analysées.")
    end
    return true
end

-- Capture aussi les recherches HDV effectuées manuellement par le joueur.
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
