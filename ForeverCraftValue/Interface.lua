local ADDON, FLM = ...

local window
local rows = {}
local professionTabs = {}
local sortDescending = true
local ROW_HEIGHT = 32
local PROFESSION_ICONS = {
    {"travail du cuir", "Trade_LeatherWorking"}, {"cuir", "Trade_LeatherWorking"},
    {"forge", "Trade_BlackSmithing"}, {"blacksmith", "Trade_BlackSmithing"},
    {"ingénierie", "Trade_Engineering"}, {"ingenierie", "Trade_Engineering"}, {"engineering", "Trade_Engineering"},
    {"couture", "Trade_Tailoring"}, {"tailoring", "Trade_Tailoring"},
    {"alchimie", "Trade_Alchemy"}, {"alchemy", "Trade_Alchemy"},
    {"enchantement", "Trade_Enchanting"}, {"enchanting", "Trade_Enchanting"},
    {"herboristerie", "Trade_Herbalism"}, {"herborisme", "Trade_Herbalism"}, {"herbalism", "Trade_Herbalism"},
    {"minage", "Trade_Mining"}, {"mining", "Trade_Mining"},
    {"dépeçage", "Trade_Skinning"}, {"depecage", "Trade_Skinning"}, {"skinning", "Trade_Skinning"},
    {"joaillerie", "Trade_Jewelcrafting"}, {"jewelcrafting", "Trade_Jewelcrafting"},
    {"calligraphie", "Trade_Inscription"}, {"inscription", "Trade_Inscription"},
    {"cuisine", "INV_Misc_Food_15"}, {"cooking", "INV_Misc_Food_15"},
    {"pêche", "Trade_Fishing"}, {"peche", "Trade_Fishing"}, {"fishing", "Trade_Fishing"},
}
local function GetProfessionIcon(name)
    local lower = string.lower(tostring(name or ""))
    for _, entry in ipairs(PROFESSION_ICONS) do
        if string.find(lower, entry[1], 1, true) then
            return "Interface\\Icons\\" .. entry[2]
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

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

local function OpenRecipe(recipeID)
    if not recipeID then return end
    if C_TradeSkillUI then
        if C_TradeSkillUI.OpenRecipe then
            C_TradeSkillUI.OpenRecipe(recipeID)
            return
        elseif C_TradeSkillUI.SelectRecipe then
            C_TradeSkillUI.SelectRecipe(recipeID)
            return
        end
    end
    FLM:Print("Sélection directe indisponible sur ce client. Ouvre le métier concerné et réessaie.")
end

local function CreateResultRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if index % 2 == 0 then
        row.bg:SetColorTexture(1, 1, 1, 0.035)
    else
        row.bg:SetColorTexture(0, 0, 0, 0.12)
    end

    row.nameButton = CreateFrame("Button", nil, row)
    row.nameButton:SetPoint("LEFT", 7, 0)
    row.nameButton:SetSize(270, ROW_HEIGHT)
    row.name = MakeFont(row.nameButton, 11, "", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 0, -2)
    row.name:SetWidth(265)
    row.age = MakeFont(row.nameButton, 9, "", "GameFontDisableSmall")
    row.age:SetPoint("BOTTOMLEFT", 0, 1)
    row.age:SetWidth(265)
    row.age:SetJustifyH("LEFT")
    row.age:SetWordWrap(false)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.nameButton:SetScript("OnClick", function()
        if row.recipeID then OpenRecipe(row.recipeID) end
    end)
    row.nameButton:SetScript("OnEnter", function()
        row.name:SetTextColor(1, 0.82, 0)
        GameTooltip:SetOwner(row.nameButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Cliquer pour ouvrir cette recette")
        GameTooltip:Show()
    end)
    row.nameButton:SetScript("OnLeave", function()
        row.name:SetTextColor(0.9, 0.9, 0.9)
        GameTooltip:Hide()
    end)

    row.cost = MakeColumn(row, "", 110, "RIGHT")
    row.cost:SetPoint("RIGHT", row, "RIGHT", -450, 0)
    row.sale = MakeColumn(row, "", 110, "RIGHT")
    row.sale:SetPoint("RIGHT", row, "RIGHT", -328, 0)
    row.deposit = MakeColumn(row, "", 110, "RIGHT")
    row.deposit:SetPoint("RIGHT", row, "RIGHT", -205, 0)
    row.profit = MakeColumn(row, "", 110, "RIGHT")
    row.profit:SetPoint("RIGHT", row, "RIGHT", -82, 0)
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

local function SortResults(results)
    table.sort(results, function(a, b)
        local pa, pb = tonumber(a.profit), tonumber(b.profit)
        if pa == nil and pb == nil then return (a.name or "") < (b.name or "") end
        if pa == nil then return false end
        if pb == nil then return true end
        if pa == pb then return (a.name or "") < (b.name or "") end
        if sortDescending then return pa > pb end
        return pa < pb
    end)
end

function FLM:ShowWindow()
    if not window then
        window = CreateFrame("Frame", "ForeverCraftValueFrame", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(950, 540)
        window:SetFrameStrata("DIALOG")
        window:SetToplevel(true)
        window:SetPoint("CENTER")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)

        window.title = MakeFont(window, 14, "Forever CraftValue - Optimiseur de métiers")
        window.title:SetPoint("TOP", 0, -8)
        window.help = MakeFont(window, 11, "Importe tes métiers puis lance un scan ciblé des objets utiles aux crafts. Le scan complet reste disponible.")
        window.help:SetPoint("TOPLEFT", 16, -38)

        window.professionButton = MakeButton(window, "Importer recettes", 135, function()
            FLM:ImportProfessionRecipes()
        end)
        window.professionButton:SetPoint("TOPLEFT", 16, -58)

        window.scanButton = MakeButton(window, "Scan ciblé", 105, function()
            FLM:StartAuctionScan("targeted")
        end)
        window.scanButton:SetPoint("LEFT", window.professionButton, "RIGHT", 8, 0)
        window.fullScanButton = MakeButton(window, "Scan complet", 100, function()
            FLM:StartAuctionScan("full")
        end)
        window.fullScanButton:SetPoint("LEFT", window.scanButton, "RIGHT", 6, 0)
        window.refreshButton = MakeButton(window, "Actualiser", 90, function()
            FLM:RefreshWindow()
        end)
        window.refreshButton:SetPoint("LEFT", window.fullScanButton, "RIGHT", 6, 0)
        window.refreshButton:SetEnabled(false)
        window.refreshButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Actualisation automatique")
            GameTooltip:AddLine("Les résultats se mettent à jour après les scans et les changements de données.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        window.refreshButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

        window.durationLabel = MakeFont(window, 11, "Durée :")
        window.durationLabel:SetPoint("LEFT", window.refreshButton, "RIGHT", 14, 0)
        window.durationButtons = {}
        for _, hours in ipairs({2, 8, 24}) do
            local durationHours = hours
            local button = MakeButton(window, durationHours .. " h", 48, function()
                FLM:SetAuctionDuration(durationHours)
            end)
            if hours == 2 then
                button:SetPoint("LEFT", window.durationLabel, "RIGHT", 6, 0)
            else
                button:SetPoint("LEFT", window.durationButtons[hours == 8 and 2 or 8], "RIGHT", 4, 0)
            end
            window.durationButtons[hours] = button
        end

        window.searchLabel = MakeFont(window, 11, "Rechercher :")
        window.searchLabel:SetPoint("TOPLEFT", 16, -120)
        window.searchBox = CreateFrame("EditBox", "FCVRecipeSearchBox", window, "InputBoxTemplate")
        window.searchBox:SetSize(230, 24)
        window.searchBox:SetPoint("LEFT", window.searchLabel, "RIGHT", 8, 0)
        window.searchBox:SetAutoFocus(false)
        window.searchBox:SetMaxLetters(80)
        window.searchBox:SetScript("OnTextChanged", function()
            FLM:RefreshWindow()
        end)
        window.clearSearchButton = MakeButton(window, "Effacer", 65, function()
            window.searchBox:SetText("")
            window.searchBox:ClearFocus()
        end)
        window.clearSearchButton:SetPoint("LEFT", window.searchBox, "RIGHT", 6, 0)

        window.status = MakeFont(window, 10, "")
        window.status:SetPoint("BOTTOMLEFT", 16, 13)
        window.status:SetWidth(850)
        window.status:SetJustifyH("LEFT")

        local header = CreateFrame("Frame", nil, window)
        header:SetPoint("TOPLEFT", 14, -150)
        header:SetPoint("TOPRIGHT", -96, -150)
        header:SetHeight(20)
        local hName = MakeColumn(header, "RECETTE", 270, "LEFT")
        hName:SetPoint("LEFT", 7, 0)
        local hCost = MakeColumn(header, "COÛT FABRICATION", 110, "RIGHT")
        hCost:SetPoint("RIGHT", header, "RIGHT", -450, 0)
        local hSale = MakeColumn(header, "VENTE NETTE", 110, "RIGHT")
        hSale:SetPoint("RIGHT", header, "RIGHT", -328, 0)
        local hDeposit = MakeColumn(header, "DÉPÔT*", 110, "RIGHT")
        hDeposit:SetPoint("RIGHT", header, "RIGHT", -205, 0)

        window.sortButton = CreateFrame("Button", nil, header)
        window.sortButton:SetSize(110, 20)
        window.sortButton:SetPoint("RIGHT", header, "RIGHT", -82, 0)
        window.sortLabel = MakeFont(window.sortButton, 11, "BÉNÉFICE ▼", "GameFontNormal")
        window.sortLabel:SetAllPoints()
        window.sortLabel:SetJustifyH("RIGHT")
        window.sortButton:SetScript("OnClick", function()
            sortDescending = not sortDescending
            window.sortLabel:SetText(sortDescending and "BÉNÉFICE ▼" or "BÉNÉFICE ▲")
            FLM:RefreshWindow()
        end)

        local hMargin = MakeColumn(header, "MARGE", 65, "RIGHT")
        hMargin:SetPoint("RIGHT", header, "RIGHT", -7, 0)
        local separator = window:CreateTexture(nil, "ARTWORK")
        separator:SetColorTexture(0.8, 0.65, 0.25, 0.65)
        separator:SetHeight(1)
        separator:SetPoint("TOPLEFT", 16, -170)
        separator:SetPoint("TOPRIGHT", -96, -170)

        window.scroll = CreateFrame("ScrollFrame", "FLMResultsScrollFrame", window, "UIPanelScrollFrameTemplate")
        window.scroll:SetPoint("TOPLEFT", 16, -175)
        window.scroll:SetPoint("BOTTOMRIGHT", -96, 42)
        window.scroll:SetClipsChildren(true)
        window.scrollChild = CreateFrame("Frame", nil, window.scroll)
        window.scrollChild:SetWidth(840)
        window.scrollChild:SetHeight(1)
        window.scroll:SetScrollChild(window.scrollChild)

        window.empty = MakeFont(window, 12, "Aucun résultat calculable pour le moment. Importe tes recettes et renseigne les prix via le scan HDV.")
        window.empty:SetPoint("CENTER", 0, -35)
        window.empty:SetWidth(690)
        window.empty:SetJustifyH("CENTER")
    end
    window:Show()
    window:Raise()
    self:RefreshWindow()
end

function FLM:RefreshWindow()
    if not window or not self.DB then return end
    local names = self:GetAvailableProfessions()
    for i, name in ipairs(names) do
        local tabIndex = i
        if not professionTabs[tabIndex] then
            local button = CreateFrame("Button", nil, window)
            button:SetSize(36, 36)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("TOPLEFT", 3, -3)
            button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
            button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            button.selection = button:CreateTexture(nil, "OVERLAY")
            button.selection:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            button.selection:SetBlendMode("ADD")
            button.selection:SetAllPoints()
            button:SetScript("OnClick", function()
                local selectedName = professionTabs[tabIndex].professionName
                if selectedName then FLM:SetActiveProfession(selectedName) end
            end)
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(self.professionName or "")
                GameTooltip:AddLine("Afficher les recettes de ce métier", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            professionTabs[tabIndex] = button
        end
        local tab = professionTabs[i]
        tab.professionName = name
        tab.icon:SetTexture(GetProfessionIcon(name))
        tab:ClearAllPoints()
        tab:SetPoint("TOPRIGHT", window, "TOPRIGHT", -9, -88 - (i - 1) * 39)
        tab.selection:SetShown(name == self.DB.activeProfession)
        tab:Show()
    end
    for i = #names + 1, #professionTabs do professionTabs[i]:Hide() end

    local results = self:CalculateDeals() or {}
    local query = ""
    if window.searchBox then
        query = string.lower(window.searchBox:GetText() or "")
        query = query:gsub("^%s+", ""):gsub("%s+$", "")
    end
    if query ~= "" then
        local filtered = {}
        for _, deal in ipairs(results) do
            local recipeName = string.lower(tostring(deal.name or ""))
            local itemName = ""
            if deal.outputItemID and GetItemInfo then
                itemName = string.lower(tostring(GetItemInfo(deal.outputItemID) or ""))
            end
            if string.find(recipeName, query, 1, true) or string.find(itemName, query, 1, true) then
                filtered[#filtered + 1] = deal
            end
        end
        results = filtered
    end
    SortResults(results)

    for i = 1, #results do
        if not rows[i] then rows[i] = CreateResultRow(window.scrollChild, i) end
        local row = rows[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", window.scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", window.scrollChild, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
        local deal = results[i]
        row.recipeID = deal.recipeID
        row.name:SetText(deal.name or ("Recette " .. tostring(deal.recipeID or "?")))
        if deal.pricesComplete then
            row.age:SetText("Prix de vente : " .. self:FormatPriceAge(deal.salePriceUpdated))
        else
            local missing = (deal.missingMaterials or 0) + (deal.netSale and 0 or 1)
            row.age:SetText("Prix manquants : " .. missing .. " élément(s)")
        end
        row.cost:SetText(deal.materialCost and self:FormatMoneyIcons(deal.materialCost) or "—")
        row.sale:SetText(deal.netSale and self:FormatMoneyIcons(deal.netSale) or "—")
        row.deposit:SetText(deal.depositCost and self:FormatMoneyIcons(deal.depositCost) or "—")
        row.deposit:SetTextColor(0.95, 0.78, 0.35)
        row.deposit:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Dépôt de mise en vente")
            GameTooltip:AddLine("Rendu si l'objet se vend.", 1, 1, 1, true)
            GameTooltip:AddLine("Perdu si l'annonce expire ou est annulée.", 1, 0.6, 0.5, true)
            GameTooltip:Show()
        end)
        row.deposit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.profit:SetText(deal.profit and ((deal.profit >= 0 and "+" or "-") .. self:FormatMoneyIcons(math.abs(deal.profit))) or "—")
        row.margin:SetText(deal.margin and string.format("%.1f%%", deal.margin) or "—")
        if deal.profit and deal.profit >= 0 then
            row.profit:SetTextColor(0.25, 1, 0.35)
            row.margin:SetTextColor(0.25, 1, 0.35)
        elseif deal.profit then
            row.profit:SetTextColor(1, 0.35, 0.25)
            row.margin:SetTextColor(1, 0.35, 0.25)
        else
            row.profit:SetTextColor(0.7, 0.7, 0.7)
            row.margin:SetTextColor(0.7, 0.7, 0.7)
        end
        row:Show()
    end

    for i = #results + 1, #rows do rows[i]:Hide() end
    window.scrollChild:SetHeight(math.max(1, #results * ROW_HEIGHT))
    window.scroll:SetVerticalScroll(0)
    window.empty:SetShown(#results == 0)
    if #results == 0 and query ~= "" then
        window.empty:SetText("Aucune recette ou aucun objet fabriqué ne correspond à « " .. query .. " ».")
    else
        window.empty:SetText("Aucune recette importée pour ce métier. Ouvre le métier en jeu puis clique sur « Importer recettes ».")
    end

    local recipeCount = #(self.DB.recipes or {})
    local priceCount = CountEntries(self.DB.prices)
    local scanText = self.DB.lastScan and self.DB.lastScan > 0
        and (date("%d/%m %H:%M", self.DB.lastScan) .. " (" ..
            (self.DB.lastScanMode == "full" and "complet" or "ciblé") .. ")") or "jamais"
    local duration = tonumber(self.DB.ahDuration) or 8
    for hours, button in pairs(window.durationButtons or {}) do
        button:SetEnabled(hours ~= duration)
    end
    window.status:SetText(string.format(
        "%s | %d recettes apprises | %d objets avec prix | %d recettes calculables | Dernier scan : %s | Prix consultés : MAJ auto | Commission : %.0f%% | Durée : %dh",
        self.DB.activeProfession or "Aucun métier sélectionné", recipeCount, priceCount, #results, scanText,
        (tonumber(self.DB.ahCut) or 0.05) * 100, duration
    ))
end
