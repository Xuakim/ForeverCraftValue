local ADDON, FLM = ...

local function ResolveMerchantItemID(index)
    if type(_G.GetMerchantItemID) == "function" then
        local ok, itemID = pcall(_G.GetMerchantItemID, index)
        if ok and itemID then return tonumber(itemID) end
    end
    if type(_G.GetMerchantItemLink) == "function" then
        local ok, link = pcall(_G.GetMerchantItemLink, index)
        if ok and link then
            if type(_G.GetItemInfoInstant) == "function" then
                local good, itemID = pcall(_G.GetItemInfoInstant, link)
                if good and itemID then return tonumber(itemID) end
            end
            return tonumber(string.match(link, "item:(%d+)"))
        end
    end
    return nil
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
    local itemCount = 0
    if MerchantFrame and MerchantFrame:IsShown() then
        itemCount = tonumber(MerchantFrame.itemAmount) or 0
        if itemCount == 0 and type(MerchantFrame.GetItemInfo) == "function" then
            for index = 1, 200 do
                local ok, info = pcall(MerchantFrame.GetItemInfo, MerchantFrame, index)
                if not ok or not info then break end
                itemCount = index
            end
        end
    end
    if itemCount == 0 and type(_G.GetMerchantNumItems) == "function" then
        local ok, count = pcall(_G.GetMerchantNumItems)
        if ok then itemCount = tonumber(count) or 0 end
    end
    -- Le compteur de visite reflète les emplacements affichés, même si le client
    -- n'a pas encore fourni les liens d'objets.
    seenItems = itemCount
    for index = 1, itemCount do
        local price, stackCount, isPurchasable, extendedCost, currencyID
        if type(_G.GetMerchantItemInfo) == "function" then
            local ok, _, _, p, stack, _, purchasable, _, ext, currency = pcall(_G.GetMerchantItemInfo, index)
            if ok then price, stackCount, isPurchasable, extendedCost, currencyID = p, stack, purchasable, ext, currency end
        end
        local itemID = ResolveMerchantItemID(index)
        if (not itemID or not price or price == 0) and MerchantFrame and type(MerchantFrame.GetItemInfo) == "function" then
            local ok, info = pcall(MerchantFrame.GetItemInfo, MerchantFrame, index)
            if ok and type(info) == "table" then
                itemID = itemID or tonumber(info.itemID)
                if not price or tonumber(price) == 0 then price = info.price end
                stackCount = stackCount or info.stackCount
                if info.isPurchasable ~= nil then isPurchasable = info.isPurchasable end
                if info.hasExtendedCost ~= nil then extendedCost = info.hasExtendedCost end
                currencyID = currencyID or info.currencyID
            end
        end
        if itemID then resolvedItems = resolvedItems + 1 end
        price = tonumber(price)
        stackCount = math.max(1, tonumber(stackCount) or 1)
        -- Ne pas filtrer sur isPurchasable : selon la version du client,
        -- ce booléen décrit l'utilisabilité du personnage, pas l'existence du prix.
        if itemID and price and price > 0
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
