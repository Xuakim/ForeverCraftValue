local ADDON, FLM = ...

local window
local rows = {}
local MAX_ROWS = 14

local function MakeFont(parent, size, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
    fs:SetText(text or "")
    return fs
end

local function MakeButton(parent, label, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 25)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

local function MakeColumn(parent, text, width, justify)
    local fs = MakeFont(parent, 11, text, "GameFontNormal")
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function CreateResultRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(23)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -117 - (index - 1) * 24)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, -117 - (index - 1) * 24)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if index % 2 == 0 then
        row.bg:SetColorTexture(1, 1, 1, 0.035)
    else
        row.bg:SetColorTexture(0, 0, 0, 0.12)
    end

    row.name = MakeColumn(row, "", 270, "LEFT")
    row.name:SetPoint("LEFT", 7, 0)

    row.cost = MakeColumn(row, "", 105, "RIGHT")
    row.cost:SetPoint("RIGHT", row, "RIGHT", -330, 0)

    row.sale = MakeColumn(row, "", 105, "RIGHT")
    row.sale:SetPoint("RIGHT", row, "RIGHT", -210, 0)

    row.profit = MakeColumn(row, "", 105, "RIGHT")
    row.profit:SetPoint("RIGHT", row, "RIGHT", -92, 0)

    row.margin = MakeColumn(row, "", 65, "RIGHT")
    row.margin:SetPoint("RIGHT", row, "RIGHT", -7, 0)

    row:Hide()
    return row
end

local function CountEntries(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

function FLM:ShowWindow()
    if not window then
        window = CreateFrame("Frame", "ForeverLeatherMasterFrame", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(790, 500)
        window:SetPoint("CENTER")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)

        window.title = MakeFont(window, 14, "Forever Leather Master - Optimiseur du Travail du cuir")
        window.title:SetPoint("TOP", 0, -8)

        window.help = MakeFont(window, 11,
            "Importe tes recettes apprises, puis scanne l'HDV. Les montants sont calculés par fabrication.")
        window.help:SetPoint("TOPLEFT", 16, -38)

        window.professionButton = MakeButton(window, "Importer recettes", 135, function()
            FLM:ImportLeatherworkingRecipes()
        end)
        window.professionButton:SetPoint("TOPLEFT", 16, -58)

        window.scanButton = MakeButton(window, "Scanner l'HDV", 115, function()
            FLM:StartAuctionScan()
        end)
        window.scanButton:SetPoint("LEFT", window.professionButton, "RIGHT", 8, 0)

        window.refreshButton = MakeButton(window, "Actualiser", 100, function()
            FLM:RefreshWindow()
        end)
        window.refreshButton:SetPoint("LEFT", window.scanButton, "RIGHT", 8, 0)

        window.status = MakeFont(window, 10, "")
        window.status:SetPoint("BOTTOMLEFT", 16, 13)
        window.status:SetWidth(740)
        window.status:SetJustifyH("LEFT")

        local header = CreateFrame("Frame", nil, window)
        header:SetPoint("TOPLEFT", 14, -94)
        header:SetPoint("TOPRIGHT", -14, -94)
        header:SetHeight(20)

        local hName = MakeColumn(header, "RECETTE", 270, "LEFT")
        hName:SetPoint("LEFT", 7, 0)

        local hCost = MakeColumn(header, "COÛT FABRICATION", 105, "RIGHT")
        hCost:SetPoint("RIGHT", header, "RIGHT", -330, 0)

        local hSale = MakeColumn(header, "VENTE NETTE", 105, "RIGHT")
        hSale:SetPoint("RIGHT", header, "RIGHT", -210, 0)

        local hProfit = MakeColumn(header, "BÉNÉFICE NET", 105, "RIGHT")
        hProfit:SetPoint("RIGHT", header, "RIGHT", -92, 0)

        local hMargin = MakeColumn(header, "MARGE", 65, "RIGHT")
        hMargin:SetPoint("RIGHT", header, "RIGHT", -7, 0)

        local separator = window:CreateTexture(nil, "ARTWORK")
        separator:SetColorTexture(0.8, 0.65, 0.25, 0.65)
        separator:SetHeight(1)
        separator:SetPoint("TOPLEFT", 16, -114)
        separator:SetPoint("TOPRIGHT", -16, -114)

        window.empty = MakeFont(window, 12,
            "Aucun résultat calculable pour le moment. Importe tes recettes et renseigne les prix via le scan HDV.")
        window.empty:SetPoint("CENTER", 0, -35)
        window.empty:SetWidth(690)
        window.empty:SetJustifyH("CENTER")

        for i = 1, MAX_ROWS do
            rows[i] = CreateResultRow(window, i)
        end
    end

    window:Show()
    self:RefreshWindow()
end

function FLM:RefreshWindow()
    if not window or not self.DB then return end

    local results = self:CalculateDeals()
    local shown = math.min(#results, MAX_ROWS)

    for i = 1, MAX_ROWS do
        local row = rows[i]
        local deal = results[i]

        if deal then
            row.name:SetText(deal.name or ("Recette " .. tostring(deal.recipeID or "?")))
            row.cost:SetText(self:FormatGold(deal.materialCost))
            row.sale:SetText(self:FormatGold(deal.netSale))
            row.profit:SetText((deal.profit >= 0 and "+" or "") .. self:FormatGold(deal.profit))
            row.margin:SetText(string.format("%.1f%%", deal.margin or 0))

            if deal.profit >= 0 then
                row.profit:SetTextColor(0.25, 1, 0.35)
                row.margin:SetTextColor(0.25, 1, 0.35)
            else
                row.profit:SetTextColor(1, 0.35, 0.25)
                row.margin:SetTextColor(1, 0.35, 0.25)
            end
            row:Show()
        else
            row:Hide()
        end
    end

    local recipeCount = #(self.DB.recipes or {})
    local priceCount = CountEntries(self.DB.prices)
    local scanText = self.DB.lastScan and self.DB.lastScan > 0
        and date("%d/%m %H:%M", self.DB.lastScan) or "jamais"

    window.empty:SetShown(shown == 0)
    window.status:SetText(string.format(
        "%d recettes apprises | %d objets avec prix | %d recettes calculables | Scan : %s | Commission HDV : %.1f%%",
        recipeCount, priceCount, #results, scanText,
        (tonumber(self.DB.ahCut) or 0.05) * 100
    ))
end
