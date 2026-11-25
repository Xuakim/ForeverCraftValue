local ADDON, FLM = ...

local function ResolveMerchantItemID(index)
    -- Certains clients exposent directement l'ID, même quand le lien n'est
    -- pas encore disponible.
    if GetMerchantItemID then
        local itemID = _G.GetMerchantItemID(index)
        if itemID then return tonumber(itemID) end
    end

    local link
    if GetMerchantItemLink then link = GetMerchantItemLink(index) end
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
    self.DB.merchantVisits = self.DB.merchantVisits or {}

    local captured, seenItems, changed = 0, 0, false
    local resolvedItems, eligibleItems = 0, 0
    local itemCount = (GetMerchantNumItems and GetMerchantItemInfo) and (GetMerchantNumItems() or 0) or 0
    -- Le compteur de visite reflète les emplacements affichés, même si le client
    -- n'a pas encore fourni les liens d'objets.
    seenItems = itemCount
    for index = 1, itemCount do
        local _, _, price, stackCount, _, isPurchasable, _, extendedCost, currencyID = GetMerchantItemInfo(index)
        local itemID = ResolveMerchantItemID(index)
        if itemID then resolvedItems = resolvedItems + 1 end
        price = tonumber(price)
        stackCount = math.max(1, tonumber(stackCount) or 1)
        if itemID and price and price > 0 and isPurchasable ~= false
            and not extendedCost and (not currencyID or currencyID == 0) then
            eligibleItems = eligibleItems + 1
            local unitPrice = math.floor(price / stackCount)
            if unitPrice > 0 then
                if self.DB.merchantPrices[itemID] ~= unitPrice then changed = true end
                self.DB.merchantPrices[itemID] = unitPrice
                self.DB.merchantPriceUpdated[itemID] = time()
                captured = captured + 1
            end
        end
    end

    local name, zone = GetCurrentMerchantIdentity()
    local key = string.lower(name .. "|" .. zone)
    local visit = self.DB.merchantVisits[key]
    local visitChanged = false

    if isNewVisit then
        local firstVisit = not visit
        if not visit then
            visit = { name = name, zone = zone, firstVisit = time(), visits = 0, items = 0 }
            self.DB.merchantVisits[key] = visit
        end
        visit.visits = (tonumber(visit.visits) or 0) + 1
        visit.lastVisit = time()
        if firstVisit then self:Print("Nouveau marchand recensé : " .. name .. " (" .. zone .. ").") end
        visitChanged = true
    end

    -- Le nombre d'articles vus correspond au stock affiché par le marchand,
    -- pas uniquement aux objets dont le lien est déjà chargé.
    if visit and seenItems > (tonumber(visit.items) or 0) then
        visit.items = seenItems
        visitChanged = true
    end

    if changed or visitChanged then
        self:Refresh()
        if self.RefreshMerchantCollector then self:RefreshMerchantCollector() end
    end
    if changed then self:Print(string.format("Prix marchand actualisés (%d article(s)).", captured)) end
    return captured, itemCount, resolvedItems, eligibleItems
end

local merchantFrame = CreateFrame("Frame")
merchantFrame:RegisterEvent("MERCHANT_SHOW")
merchantFrame:RegisterEvent("MERCHANT_UPDATE")
merchantFrame:SetScript("OnEvent", function(_, event)
    -- Enregistre la visite, puis relit le stock après le chargement asynchrone de l'interface.
    local captured, count, resolved, eligible = FLM:CaptureMerchantPrices(event == "MERCHANT_SHOW")
    if event == "MERCHANT_SHOW" then
        FLM:Print(string.format("Marchand détecté : %d article(s) affiché(s), %d identifiant(s) récupéré(s), %d prix enregistré(s).", count or 0, resolved or 0, captured or 0))
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function() FLM:CaptureMerchantPrices(false) end)
            C_Timer.After(1.5, function()
                local saved, total, ids, valid = FLM:CaptureMerchantPrices(false)
                FLM:Print(string.format("Diagnostic marchand : stock=%d, IDs=%d, articles achetables en or=%d, prix sauvegardés=%d.", total or 0, ids or 0, valid or 0, saved or 0))
            end)
        end
    end
end)
