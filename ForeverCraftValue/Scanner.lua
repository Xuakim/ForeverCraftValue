local ADDON, FLM = ...
local scannerFrame = CreateFrame("Frame")
local replicateScanning = false
local processIndex, totalAuctions, processed, validOffers = 0, 0, 0, 0
local targetedQueue, targetedIndex = nil, 0
local targetedPendingItemID, targetedDeadline, targetedNextQueryAt
local targetedCompleted, targetedTotal = 0, 0
local TARGET_QUERY_INTERVAL, TARGET_QUERY_TIMEOUT = 0.70, 5

local function CaptureItemSearch(itemKey)
    if not itemKey or not itemKey.itemID or not C_AuctionHouse then return end
    local itemID = tonumber(itemKey.itemID)
    local prices = {}
    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    for i = 1, count do
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if info and info.buyoutAmount and info.buyoutAmount > 0 then
            prices[#prices + 1] = math.floor(info.buyoutAmount / math.max(1, tonumber(info.quantity) or 1))
        end
    end
    if #prices > 0 then FLM:UpdatePriceFromListings(itemID, prices) end
end

local function CaptureCommoditySearch(itemID)
    itemID = tonumber(itemID)
    if not itemID or not C_AuctionHouse then return end
    local prices = {}
    local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    for i = 1, count do
        local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if info and info.unitPrice and info.unitPrice > 0 then prices[#prices + 1] = info.unitPrice end
    end
    if #prices > 0 then FLM:UpdatePriceFromListings(itemID, prices) end
end

local function FinishTargetedScan()
    local completed, total = targetedCompleted, targetedTotal
    targetedQueue, targetedPendingItemID = nil, nil
    targetedIndex, targetedCompleted, targetedTotal = 0, 0, 0
    FLM.DB.lastScan = time()
    FLM.DB.lastScanMode = "targeted"
    FLM.DB.lastTargetedScan = FLM.DB.lastScan
    FLM.DB.lastScanCount = completed
    FLM:Print(string.format("Scan ciblé terminé : %d/%d recherches effectuées.", completed, total))
    FLM:Refresh()
end

local function StartNextTargetedQuery()
    if not targetedQueue then return end
    if targetedIndex > targetedTotal then FinishTargetedScan() return end
    local itemID = targetedQueue[targetedIndex]
    targetedIndex = targetedIndex + 1
    targetedPendingItemID = itemID
    targetedDeadline = GetTime() + TARGET_QUERY_TIMEOUT
    targetedNextQueryAt = GetTime() + TARGET_QUERY_INTERVAL
    local itemKey = C_AuctionHouse.MakeItemKey and C_AuctionHouse.MakeItemKey(itemID) or { itemID = itemID }
    local ok, result = pcall(C_AuctionHouse.SendSearchQuery, itemKey, {}, false)
    if not ok or result == false then
        FLM:Print("Recherche impossible pour l'objet " .. itemID .. " : " .. tostring(result))
        targetedPendingItemID = nil
        targetedCompleted = targetedCompleted + 1
    end
end

local function FinishReplicationScan()
    replicateScanning = false
    local prices, itemCount, offerCount = FLM:FinalizeAuctionPrices()
    FLM.DB.prices = prices
    FLM.DB.lastScan = time()
    FLM.DB.lastScanCount = processed
    FLM.DB.lastScanMode = "full"
    FLM.DB.lastFullScan = FLM.DB.lastScan
    FLM:Print(string.format("Scan complet terminé : %d annonces, %d offres, %d objets actualisés.", processed, offerCount or validOffers, itemCount))
    FLM:Refresh()
end

local function ProcessReplicationBatch()
    if not replicateScanning then return end
    local limit = math.min(processIndex + 99, totalAuctions - 1)
    local startedAt = GetTime()
    while processIndex <= limit do
        local name, texture, count, quality, usable, level, levelType,
            minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
            bidderFullName, owner, ownerFullName, saleStatus, itemID =
            C_AuctionHouse.GetReplicateItemInfo(processIndex)
        if itemID and buyoutPrice and buyoutPrice > 0 and FLM:RecordAuctionPrice(itemID, buyoutPrice, count) then
            validOffers = validOffers + 1
        end
        processed = processed + 1
        processIndex = processIndex + 1
        if GetTime() - startedAt >= 0.003 then break end
    end
    if processIndex >= totalAuctions then FinishReplicationScan() end
end

scannerFrame:SetScript("OnUpdate", function()
    if replicateScanning then
        ProcessReplicationBatch()
    elseif targetedQueue then
        if targetedPendingItemID then
            if GetTime() >= targetedDeadline then
                targetedPendingItemID = nil
                targetedCompleted = targetedCompleted + 1
                targetedNextQueryAt = GetTime() + TARGET_QUERY_INTERVAL
            end
        elseif GetTime() >= (targetedNextQueryAt or 0) then
            StartNextTargetedQuery()
        end
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED")
eventFrame:SetScript("OnEvent", function(_, event, payload)
    if event == "REPLICATE_ITEM_LIST_UPDATE" then
        if not FLM.waitingForReplication then return end
        FLM.waitingForReplication = false
        totalAuctions = C_AuctionHouse.GetNumReplicateItems() or 0
        processIndex, processed, validOffers = 0, 0, 0
        FLM.scanObservations = {}
        replicateScanning = true
        if totalAuctions == 0 then FinishReplicationScan()
        else FLM:Print("Analyse du scan complet : " .. totalAuctions .. " annonces.") end
        return
    end

    local resultItemID
    if event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
        if payload and payload.itemID then
            resultItemID = tonumber(payload.itemID)
            CaptureItemSearch(payload)
        end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED" then
        resultItemID = tonumber(payload)
        CaptureCommoditySearch(payload)
    end
    if targetedQueue and targetedPendingItemID and resultItemID == targetedPendingItemID then
        targetedPendingItemID = nil
        targetedCompleted = targetedCompleted + 1
        targetedNextQueryAt = GetTime() + TARGET_QUERY_INTERVAL
        if targetedCompleted % 20 == 0 or targetedCompleted == targetedTotal then
            FLM:Print(string.format("Scan ciblé : %d/%d objets interrogés.", targetedCompleted, targetedTotal))
        end
    end
end)

function FLM:StartAuctionScan(mode)
    mode = mode or "targeted"
    if mode ~= "targeted" and mode ~= "full" then return false end
    if not C_AuctionHouse or not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
        self:Print("Ouvre l'hôtel des ventes avant de lancer le scan.") return false
    end
    if self.waitingForReplication or replicateScanning or targetedQueue then
        self:Print("Un scan est déjà en cours.") return false
    end
    if mode == "targeted" then
        if not C_AuctionHouse.SendSearchQuery or not C_AuctionHouse.GetNumItemSearchResults or not C_AuctionHouse.GetItemSearchResultInfo then
            self:Print("Les recherches HDV ciblées ne sont pas disponibles sur ce client.") return false
        end
        local wanted = self:BuildRelevantItemIDs()
        local queue = {}
        for itemID in pairs(wanted or {}) do
            itemID = tonumber(itemID)
            if itemID and itemID > 0 then queue[#queue + 1] = itemID end
        end
        table.sort(queue)
        if #queue == 0 then self:Print("Aucun objet nécessaire : importe d'abord les recettes.") return false end
        targetedQueue = queue
        targetedIndex, targetedCompleted, targetedTotal = 1, 0, #queue
        targetedPendingItemID = nil
        targetedNextQueryAt = GetTime()
        self:Print(string.format("Scan ciblé lancé : %d objets nécessaires aux recettes importées. Seuls ces objets sont recherchés.", #queue))
        return true
    end
    if not C_AuctionHouse.ReplicateItems or not C_AuctionHouse.GetNumReplicateItems or not C_AuctionHouse.GetReplicateItemInfo then
        self:Print("API de réplication HDV indisponible pour le scan complet.") return false
    end
    local lastFull = tonumber(self.DB.lastFullScan) or 0
    local elapsed = time() - lastFull
    if lastFull > 0 and elapsed < 900 then
        local remaining = 900 - elapsed
        self:Print(string.format("Attends encore %d min %d s avant un autre scan complet.", math.floor(remaining / 60), remaining % 60))
        return false
    end
    self.waitingForReplication = true
    local ok, err = pcall(C_AuctionHouse.ReplicateItems)
    if not ok then
        self.waitingForReplication = false
        self:Print("Le serveur a refusé le scan complet : " .. tostring(err)) return false
    end
    self:Print("Scan complet demandé : récupération de toutes les annonces HDV.")
    return true
end
