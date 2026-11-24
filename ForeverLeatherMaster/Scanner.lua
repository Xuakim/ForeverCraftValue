local ADDON, FLM = ...

local scanning = false
local processIndex = 0
local totalAuctions = 0
local processed = 0
local oldScanCount = 0
local scannerFrame = CreateFrame("Frame")

local function FinishScan()
    scanning = false
    FLM.DB.prices = FLM.scanPrices or {}
    FLM.scanPrices = nil
    FLM.DB.lastScan = time()
    FLM.DB.lastScanCount = processed
    FLM:Print(string.format("Scan terminé : %d annonces parcourues, %d objets avec prix enregistrés.",
        processed, oldScanCount))
    FLM:Refresh()
end

local function ProcessBatch()
    if not scanning then return end

    local limit = math.min(processIndex + 249, totalAuctions - 1)
    while processIndex <= limit do
        -- Returns: name, texture, count, quality, usable, level, levelType,
        -- minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
        -- bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo
        local name, texture, count, quality, usable, level, levelType,
            minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
            bidderFullName, owner, ownerFullName, saleStatus, itemID =
            C_AuctionHouse.GetReplicateItemInfo(processIndex)

        if itemID and buyoutPrice and buyoutPrice > 0 then
            if FLM:RecordAuctionPrice(itemID, buyoutPrice, count) then
                oldScanCount = oldScanCount + 1
            end
        end

        processed = processed + 1
        processIndex = processIndex + 1
    end

    if processIndex >= totalAuctions then
        FinishScan()
    end
end

scannerFrame:SetScript("OnUpdate", function(_, elapsed)
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
    processIndex, processed, oldScanCount = 0, 0, 0
    FLM.scanPrices = {}
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
