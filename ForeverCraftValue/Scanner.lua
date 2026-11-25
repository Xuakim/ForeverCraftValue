local ADDON, FLM = ...
local scannerFrame = CreateFrame("Frame")
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

scannerFrame:SetScript("OnUpdate", function()
    if targetedQueue then
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
eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED")
eventFrame:SetScript("OnEvent", function(_, event, payload)
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

function FLM:StartAuctionScan()
    if not C_AuctionHouse or not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
        self:Print("Ouvre l'hôtel des ventes avant de lancer le scan.") return false
    end
    if targetedQueue then
        self:Print("Un scan est déjà en cours.") return false
    end
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
