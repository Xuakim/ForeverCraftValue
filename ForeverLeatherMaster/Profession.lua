local ADDON, FLM = ...

local function GetProfessionLabel(info)
    if not info then return "" end
    return info.professionName or info.name or info.parentProfessionName or ""
end

function FLM:ImportLeatherworkingRecipes()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs then
        self:Print("API des métiers indisponible sur ce client.")
        return 0
    end

    local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    local professionName = GetProfessionLabel(baseInfo)

    -- Avoid importing the wrong profession if another profession window is open.
    -- The name check is intentionally permissive for localized client labels.
    local lowerName = string.lower(professionName)
    local looksLikeLeatherworking =
        (Enum and Enum.Profession and baseInfo and baseInfo.profession == Enum.Profession.Leatherworking) or
        string.find(lowerName, "leather", 1, true) or
        string.find(lowerName, "cuir", 1, true)

    if not looksLikeLeatherworking then
        self:Print("Ouvre d'abord la fenêtre du Travail du cuir, puis réessaie.")
        self:Print("Métier actuellement détecté : " .. (professionName ~= "" and professionName or "inconnu"))
        return 0
    end

    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs() or {}
    local imported, skipped = {}, 0

    for _, recipeID in ipairs(recipeIDs) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)

        local isLearned = info and (info.learned == true or info.isLearned == true)

        -- Only include recipes actually learned by this character.
        -- Unlearned recipes visible in profession lists are deliberately ignored.
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
                        table.insert(choices, reagent.itemID)
                    end
                end

                if #choices > 0 then
                    table.insert(recipe.reagents, {
                        choices = choices,
                        itemID = choices[1],
                        count = tonumber(slot.quantityRequired) or 1,
                    })
                end
            end

            if #recipe.reagents > 0 then
                table.insert(imported, recipe)
            else
                skipped = skipped + 1
            end
        else
            skipped = skipped + 1
        end
    end

    self.DB.recipes = imported
    self.DB.recipeProfession = professionName
    self.DB.recipeImportTime = time()
    self:Print(string.format("%d recettes apprises importées (%d non apprises ou incompatibles ignorées).", #imported, skipped))
    self:Refresh()
    return #imported
end
