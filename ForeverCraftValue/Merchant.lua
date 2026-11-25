local ADDON, FLM = ...

local function GetMerchantItemID(index)
    if not GetMerchantItemLink then return nil end
    local link = GetMerchantItemLink(index)
    if not link then return nil end

    if GetItemInfoInstant then
        local itemID = GetItemInfoInstant(link)
        if itemID then return tonumber(itemID) end
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function GetCurrentMerchantIdentity()
    local name
    if MerchantFrameTitleText and MerchantFrameTitleText.GetText then name = MerchantFrameTitleText:GetText() end
    if not name or name == "" then if UnitName then name = UnitName("target") end end
    if not name or name == "" then name = "Marchand inconnu" end
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Zone inconnue"
    return tostring(name), tostring(zone)
end

function FLM:CaptureMerchantPrices(isNewVisit)
    if not self.DB then return 0 end

    self.DB.merchantPrices = self.DB.merchantPrices or {}
    self.DB.merchantPriceUpdated = self.DB.merchantPriceUpdated or {}
    local captured, changed = 0, false

    local itemCount = (GetMerchantNumItems and GetMerchantItemInfo) and GetMerchantNumItems() or 0
    for index = 1, itemCount do
        local _, _, price, stackCount, _, isPurchasable, _, extendedCost, currencyID = GetMerchantItemInfo(index)
        price = tonumber(price)
        stackCount = math.max(1, tonumber(stackCount) or 1)
        local itemID = GetMerchantItemID(index)

        -- Ne retenir que les articles achetables contre de l'or.
        if itemID and price and price > 0 and isPurchasable ~= false
            and not extendedCost and (not currencyID or currencyID == 0) then
            local unitPrice = math.floor(price / stackCount)
            if unitPrice > 0 then
                if self.DB.merchantPrices[itemID] ~= unitPrice then changed = true end
                self.DB.merchantPrices[itemID] = unitPrice
                self.DB.merchantPriceUpdated[itemID] = time()
                captured = captured + 1
            end
        end
    end

    if isNewVisit then
        self.DB.merchantVisits = self.DB.merchantVisits or {}
        local name, zone = GetCurrentMerchantIdentity()
        local key = string.lower(name .. "|" .. zone)
        local visit = self.DB.merchantVisits[key]
        local firstVisit = not visit
        if not visit then
            visit = { name = name, zone = zone, firstVisit = time(), visits = 0, items = 0 }
            self.DB.merchantVisits[key] = visit
        end
        visit.visits = (tonumber(visit.visits) or 0) + 1
        visit.lastVisit = time()
        visit.items = math.max(tonumber(visit.items) or 0, captured)
        if firstVisit then self:Print("Nouveau marchand recensé : " .. name .. " (" .. zone .. ").") end
        self:Refresh()
        if self.RefreshMerchantCollector then self:RefreshMerchantCollector() end
    elseif changed then
        self:Refresh()
        if self.RefreshMerchantCollector then self:RefreshMerchantCollector() end
    end
    if changed then self:Print(string.format("Prix marchand actualisés (%d article(s)).", captured)) end
    return captured
end

local merchantFrame = CreateFrame("Frame")
merchantFrame:RegisterEvent("MERCHANT_SHOW")
merchantFrame:RegisterEvent("MERCHANT_UPDATE")
merchantFrame:SetScript("OnEvent", function(_, event)
    -- MERCHANT_SHOW peut arriver avant que les lignes du marchand soient prêtes :
    -- on enregistre immédiatement la visite, puis MERCHANT_UPDATE complète les prix.
    FLM:CaptureMerchantPrices(event == "MERCHANT_SHOW")
end)
