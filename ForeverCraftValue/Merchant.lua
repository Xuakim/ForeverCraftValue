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

function FLM:CaptureMerchantPrices()
    if not self.DB or not GetMerchantNumItems or not GetMerchantItemInfo then return 0 end

    self.DB.merchantPrices = self.DB.merchantPrices or {}
    self.DB.merchantPriceUpdated = self.DB.merchantPriceUpdated or {}
    local captured = 0

    for index = 1, GetMerchantNumItems() do
        local _, _, price, stackCount, _, isPurchasable, _, extendedCost, currencyID = GetMerchantItemInfo(index)
        price = tonumber(price)
        stackCount = math.max(1, tonumber(stackCount) or 1)
        local itemID = GetMerchantItemID(index)

        -- Ne retenir que les articles achetables contre de l'or.
        if itemID and price and price > 0 and isPurchasable ~= false
            and not extendedCost and (not currencyID or currencyID == 0) then
            local unitPrice = math.floor(price / stackCount)
            if unitPrice > 0 then
                self.DB.merchantPrices[itemID] = unitPrice
                self.DB.merchantPriceUpdated[itemID] = time()
                captured = captured + 1
            end
        end
    end

    if captured > 0 then
        self:Print(string.format("%d prix marchand(s) mémorisés.", captured))
        self:Refresh()
    end
    return captured
end

local merchantFrame = CreateFrame("Frame")
merchantFrame:RegisterEvent("MERCHANT_SHOW")
merchantFrame:RegisterEvent("MERCHANT_UPDATE")
merchantFrame:SetScript("OnEvent", function()
    FLM:CaptureMerchantPrices()
end)
