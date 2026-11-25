local ADDON, FLM = ...

local window
local rows = {}
local professionTabs = {}
local sortDescending = true
local ROW_HEIGHT = 32
local PROFESSION_ICONS = {
    {"travail du cuir", "ui_profession_leatherworking"},
    {"forge", "ui_profession_blacksmithing"},
    {"ingénierie", "ui_profession_engineering"}, {"ingenierie", "ui_profession_engineering"},
    {"couture", "ui_profession_tailoring"},
    {"alchimie", "ui_profession_alchemy"},
    {"enchantement", "ui_profession_enchanting"},
    {"herboristerie", "ui_profession_herbalism"}, {"herborisme", "ui_profession_herbalism"},
    {"minage", "ui_profession_mining"},
    {"dépeçage", "ui_profession_skinning"}, {"depecage", "ui_profession_skinning"},
    {"joaillerie", "ui_profession_jewelcrafting"},
    {"calligraphie", "ui_profession_inscription"}, {"inscription", "ui_profession_inscription"},
    {"cuisine", "ui_profession_cooking"},
    {"pêche", "ui_profession_fishing"}, {"peche", "ui_profession_fishing"},
}
local function GetProfessionIcon(name)
    -- Utiliser en priorité l'icône retournée par l'API du client pour le métier appris.
    if GetProfessions and GetProfessionInfo then
        local professionIndices = { GetProfessions() }
        for _, index in ipairs(professionIndices) do
            if index then
                local professionName, icon = GetProfessionInfo(index)
                if professionName and icon then
                    local current = string.lower(tostring(name or ""))
                    local learned = string.lower(tostring(professionName))
                    if current == learned or string.find(current, learned, 1, true)
                        or string.find(learned, current, 1, true) then
                        return icon
                    end
                end
            end
        end
    end

    -- Fallback sur les textures UI Profession natives de WoW.
    local lower = string.lower(tostring(name or ""))
    for _, entry in ipairs(PROFESSION_ICONS) do
        if string.find(lower, entry[1], 1, true) then
            return "Interface\\\\Icons\\\\" .. entry[2]
        end
    end
    return "Interface\\\\Icons\\\\INV_Misc_QuestionMark"
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
    local function StateTexture(r, g, b, a)
        local texture = button:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints(button)
        texture:SetColorTexture(r, g, b, a or 1)
        return texture
    end
    button:SetNormalTexture(StateTexture(0.20, 0.12, 0.055, 1))
    button:SetHighlightTexture(StateTexture(0.48, 0.31, 0.10, 0.65))
    button:SetPushedTexture(StateTexture(0.12, 0.07, 0.03, 1))
    local font = button:GetFontString()
    if font then
        font:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        font:SetTextColor(1, 0.84, 0.48)
    end
    return button
end

local function StyleEditBox(editBox)
    editBox:SetTextColor(0.95, 0.86, 0.68)
    editBox:SetTextInsets(7, 7, 0, 0)
    if editBox.SetBackdrop then
        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 8,
            insets = {left = 2, right = 2, top = 2, bottom = 2},
        })
        editBox:SetBackdropColor(0.08, 0.045, 0.02, 1)
        editBox:SetBackdropBorderColor(0.62, 0.42, 0.14, 1)
    end
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
        row.bg:SetColorTexture(0.34, 0.22, 0.11, 0.34)
    else
        row.bg:SetColorTexture(0.10, 0.06, 0.03, 0.42)
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
        row.name:SetTextColor(1, 0.78, 0.22)
        GameTooltip:SetOwner(row.nameButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Cliquer pour ouvrir cette recette")
        GameTooltip:Show()
    end)
    row.nameButton:SetScript("OnLeave", function()
        row.name:SetTextColor(0.94, 0.88, 0.75)
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
        window:SetSize(950, 620)
        window:SetScale(0.85)
        if window.SetBackdrop then
            window:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = {left = 11, right = 11, top = 12, bottom = 11},
            })
            window:SetBackdropColor(0.12, 0.075, 0.038, 0.97)
            window:SetBackdropBorderColor(0.78, 0.55, 0.19, 1)
        end
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
        window.title:SetTextColor(1, 0.78, 0.22)
        window.help = MakeFont(window, 11, "Importe tes métiers puis lance un scan ciblé des objets utiles aux crafts.")
        window.help:SetPoint("TOPLEFT", 16, -38)
        window.help:SetTextColor(0.78, 0.68, 0.50)

        window.professionButton = MakeButton(window, "Importer recettes", 135, function()
            FLM:ImportProfessionRecipes()
        end)
        window.professionButton:SetPoint("TOPLEFT", 16, -58)

        window.scanButton = MakeButton(window, "Scan ciblé", 105, function()
            FLM:StartAuctionScan()
        end)
        window.scanButton:SetPoint("LEFT", window.professionButton, "RIGHT", 8, 0)
        window.durationLabel = MakeFont(window, 11, "Durée :")
        window.durationLabel:SetPoint("LEFT", window.scanButton, "RIGHT", 14, 0)
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
        StyleEditBox(window.searchBox)
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
        window.status:SetTextColor(0.78, 0.66, 0.46)

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
        window.sortLabel = MakeFont(window.sortButton, 11, "BÉNÉFICE", "GameFontNormal")
        window.sortLabel:SetAllPoints()
        window.sortLabel:SetJustifyH("RIGHT")
        window.sortLabel:SetTextColor(1, 0.78, 0.22)
        window.sortButton:SetScript("OnClick", function()
            sortDescending = not sortDescending
            window.sortLabel:SetText(sortDescending and "BÉNÉFICE ▼" or "BÉNÉFICE")
            FLM:RefreshWindow()
        end)

        local hMargin = MakeColumn(header, "MARGE", 65, "RIGHT")
        hMargin:SetPoint("RIGHT", header, "RIGHT", -7, 0)
        local separator = window:CreateTexture(nil, "ARTWORK")
        separator:SetColorTexture(0.72, 0.48, 0.16, 0.95)
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
        window.empty:SetTextColor(0.78, 0.68, 0.50)
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
            button:SetSize(48, 48)
            button.tile = button:CreateTexture(nil, "BACKGROUND")
            button.tile:SetAllPoints()
            button.tile:SetColorTexture(0.16, 0.095, 0.04, 0.98)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("TOPLEFT", 4, -4)
            button.icon:SetPoint("BOTTOMRIGHT", -4, 4)
            button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            -- Bordure dorée dessinée exactement sur le carré de l'icône
            -- (l'ancienne texture ActionButton débordait de l'emplacement).
            button.selection = CreateFrame("Frame", nil, button)
            button.selection:SetPoint("TOPLEFT", button.icon, "TOPLEFT", 0, 0)
            button.selection:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 0, 0)
            button.selection:SetFrameLevel(button:GetFrameLevel() + 2)
            button.selection.top = button.selection:CreateTexture(nil, "OVERLAY")
            button.selection.top:SetColorTexture(1, 0.72, 0.16, 1)
            button.selection.top:SetPoint("TOPLEFT")
            button.selection.top:SetPoint("TOPRIGHT")
            button.selection.top:SetHeight(2)
            button.selection.bottom = button.selection:CreateTexture(nil, "OVERLAY")
            button.selection.bottom:SetColorTexture(1, 0.72, 0.16, 1)
            button.selection.bottom:SetPoint("BOTTOMLEFT")
            button.selection.bottom:SetPoint("BOTTOMRIGHT")
            button.selection.bottom:SetHeight(2)
            button.selection.left = button.selection:CreateTexture(nil, "OVERLAY")
            button.selection.left:SetColorTexture(1, 0.72, 0.16, 1)
            button.selection.left:SetPoint("TOPLEFT")
            button.selection.left:SetPoint("BOTTOMLEFT")
            button.selection.left:SetWidth(2)
            button.selection.right = button.selection:CreateTexture(nil, "OVERLAY")
            button.selection.right:SetColorTexture(1, 0.72, 0.16, 1)
            button.selection.right:SetPoint("TOPRIGHT")
            button.selection.right:SetPoint("BOTTOMRIGHT")
            button.selection.right:SetWidth(2)
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
        tab:SetPoint("TOPRIGHT", window, "TOPRIGHT", -10, -88 - (i - 1) * 51)
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
            row.profit:SetTextColor(0.35, 0.88, 0.30)
            row.margin:SetTextColor(0.35, 0.88, 0.30)
        elseif deal.profit then
            row.profit:SetTextColor(1, 0.36, 0.22)
            row.margin:SetTextColor(1, 0.36, 0.22)
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
