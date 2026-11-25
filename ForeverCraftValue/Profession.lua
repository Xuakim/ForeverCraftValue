local ADDON, FLM = ...

local function GetProfessionLabel(info)
    if not info then return "" end
    return info.professionName or info.name or info.parentProfessionName or ""
end

function FLM:GetAvailableProfessions()
    local names = {}
    for name, profession in pairs((self.DB and self.DB.professions) or {}) do
        -- Un onglet n'existe que si au moins une recette a été importée.
        if type(profession) == "table" and type(profession.recipes) == "table"
            and #profession.recipes > 0 then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

function FLM:SaveActiveProfession()
    if not self.DB then return end
    local name = self.DB.activeProfession
    if not name or name == "" then return end
    self.DB.professions = self.DB.professions or {}
    local entry = self.DB.professions[name] or {}
    entry.recipes = self.DB.recipes or {}
    entry.lastImport = entry.lastImport or self.DB.recipeImportTime or 0
    self.DB.professions[name] = entry
end

function FLM:InitializeProfessionData()
    if not self.DB then return end
    self.DB.professions = self.DB.professions or {}

    -- Migration transparente des anciennes données (versions spécialisées cuir).
    local legacyName = self.DB.recipeProfession
    if type(self.DB.recipes) == "table" and #self.DB.recipes > 0 then
        legacyName = (legacyName and legacyName ~= "") and legacyName or "Travail du cuir"
        if not self.DB.professions[legacyName] then
            self.DB.professions[legacyName] = {
                recipes = self.DB.recipes,
                lastImport = self.DB.recipeImportTime or 0,
            }
        end
    end

    local active = self.DB.activeProfession
    if not active or not self.DB.professions[active]
        or type(self.DB.professions[active].recipes) ~= "table"
        or #self.DB.professions[active].recipes == 0 then
        if legacyName and self.DB.professions[legacyName] then
            active = legacyName
        else
            local names = self:GetAvailableProfessions()
            active = names[1]
        end
    end

    self.DB.activeProfession = active
    if active and self.DB.professions[active]
        and type(self.DB.professions[active].recipes) == "table"
        and #self.DB.professions[active].recipes > 0 then
        self.DB.recipes = self.DB.professions[active].recipes
        self.DB.recipeProfession = active
    else
        self.DB.activeProfession = nil
        self.DB.recipeProfession = nil
        self.DB.recipes = {}
    end
end

function FLM:SetActiveProfession(name)
    if not self.DB or not name or not self.DB.professions or not self.DB.professions[name] then
        return false
    end
    self:SaveActiveProfession()
    self.DB.activeProfession = name
    self.DB.recipeProfession = name
    self.DB.recipes = self.DB.professions[name].recipes or {}
    self:Print("Métier affiché : " .. name)
    self:Refresh()
    return true
end

function FLM:ImportProfessionRecipes()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs
        or not C_TradeSkillUI.GetBaseProfessionInfo then
        self:Print("API des métiers indisponible sur ce client.")
        return 0
    end

    local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    local professionName = GetProfessionLabel(baseInfo)
    if professionName == "" then
        self:Print("Impossible de détecter le métier. Ouvre sa fenêtre et réessaie.")
        return 0
    end

    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs() or {}
    local imported, skipped = {}, 0

    for _, recipeID in ipairs(recipeIDs) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
        local isLearned = info and (info.learned == true or info.isLearned == true)

        if isLearned and schematic and schematic.outputItemID
            and (not Enum or not Enum.TradeskillRecipeType
                or schematic.recipeType ~= Enum.TradeskillRecipeType.Gathering) then
            local recipe = {
                recipeID = recipeID,
                name = info.name or schematic.name or ("Recette " .. recipeID),
                outputItemID = schematic.outputItemID,
                outputCount = math.max(1, tonumber(schematic.quantityMin) or 1),
                learned = true,
                reagents = {},
            }

            for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
                local choices = {}
                for _, reagent in ipairs(slot.reagents or {}) do
                    if reagent.itemID then
                        choices[#choices + 1] = reagent.itemID
                    end
                end
                if #choices > 0 then
                    recipe.reagents[#recipe.reagents + 1] = {
                        choices = choices,
                        itemID = choices[1],
                        count = tonumber(slot.quantityRequired) or 1,
                    }
                end
            end

            -- Conserver aussi les recettes sans réactifs : elles doivent apparaître
            -- dans la liste, même si leur coût de fabrication est nul ou spécial.
            imported[#imported + 1] = recipe
        else
            skipped = skipped + 1
        end
    end

    self.DB.professions = self.DB.professions or {}
    if #imported > 0 then
        self.DB.professions[professionName] = {
            recipes = imported,
            lastImport = time(),
        }
        self.DB.activeProfession = professionName
        self.DB.recipeProfession = professionName
        self.DB.recipes = imported
        self.DB.recipeImportTime = time()
    else
        -- Ne pas conserver/créer un métier vide dans la liste des onglets.
        self.DB.professions[professionName] = nil
        local names = self:GetAvailableProfessions()
        local fallback = names[1]
        self.DB.activeProfession = fallback
        self.DB.recipeProfession = fallback
        self.DB.recipes = fallback and self.DB.professions[fallback].recipes or {}
    end

    self:Print(string.format("%s : %d recettes apprises importées (%d ignorées).",
        professionName, #imported, skipped))
    self:Refresh()
    return #imported
end

-- Compatibilité avec les anciennes commandes et boutons de la version cuir.
function FLM:ImportLeatherworkingRecipes()
    return self:ImportProfessionRecipes()
end


function FLM:ClearImportedRecipes()
    if not self.DB then return end
    StaticPopupDialogs["FCV_CLEAR_IMPORTED_RECIPES"] = {
        text = "Supprimer toutes les recettes importées de tous les métiers ?\\nLes prix HDV et les autres réglages seront conservés.",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            FLM.DB.professions = {}
            FLM.DB.recipes = {}
            FLM.DB.activeProfession = nil
            FLM.DB.recipeProfession = nil
            FLM.DB.recipeImportTime = nil
            FLM:Print("Toutes les recettes importées ont été supprimées. Les prix HDV sont conservés.")
            FLM:Refresh()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("FCV_CLEAR_IMPORTED_RECIPES")
end
