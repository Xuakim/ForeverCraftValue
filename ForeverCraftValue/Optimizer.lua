local ADDON, FLM = ...

-- Compare le prix HDV et le coût de fabrication via les recettes importées.
local function BestItemCostInfo(itemID, recipesByOutput, visiting)
    itemID = tonumber(itemID)
    if not itemID then return nil, "Prix inconnu" end

    local ahPrice = tonumber(FLM.DB.prices and FLM.DB.prices[itemID])
    local best, source

    if ahPrice and ahPrice > 0 then
        best, source = ahPrice, "Hôtel des ventes"
    end

    local alternatives = recipesByOutput[itemID]
    if alternatives and not visiting[itemID] then
        visiting[itemID] = true
        for _, recipe in ipairs(alternatives) do
            local total, valid = 0, true
            for _, reagent in ipairs(recipe.reagents or {}) do
                local choices = reagent.choices or { reagent.itemID }
                local cheapest
                for _, choiceID in ipairs(choices) do
                    local choiceCost = BestItemCostInfo(choiceID, recipesByOutput, visiting)
                    if choiceCost and (not cheapest or choiceCost < cheapest) then
                        cheapest = choiceCost
                    end
                end
                if not cheapest then
                    valid = false
                    break
                end
                total = total + cheapest * (tonumber(reagent.count) or 0)
            end
            if valid then
                local craftCost = total / math.max(1, tonumber(recipe.outputCount) or 1)
                if not best or craftCost < best then
                    best = craftCost
                    source = "Fabriqué : " .. tostring(recipe.name or "recette connue")
                end
            end
        end
        visiting[itemID] = nil
    end

    return best, source or "Prix inconnu"
end

-- Construit l'ensemble des objets utiles aux recettes du métier actif.
-- Les recettes de tous les métiers importés sont utilisées pour développer
-- récursivement les composants qui peuvent eux-mêmes être fabriqués.
function FLM:BuildRelevantItemIDs()
    local relevant, recipesByOutput = {}, {}
    local activeRecipes = self.DB and self.DB.recipes or {}
    local professions = self.DB and self.DB.professions or {}

    for _, profession in pairs(professions) do
        for _, recipe in ipairs((profession and profession.recipes) or {}) do
            local outputID = tonumber(recipe.outputItemID)
            if outputID then
                recipesByOutput[outputID] = recipesByOutput[outputID] or {}
                recipesByOutput[outputID][#recipesByOutput[outputID] + 1] = recipe
            end
        end
    end

    -- Compatibilité avec les sauvegardes où les recettes ne sont pas encore
    -- rangées dans DB.professions.
    for _, recipe in ipairs(activeRecipes) do
        local outputID = tonumber(recipe.outputItemID)
        if outputID then
            recipesByOutput[outputID] = recipesByOutput[outputID] or {}
            local found = false
            for _, existing in ipairs(recipesByOutput[outputID]) do
                if existing.recipeID == recipe.recipeID then found = true break end
            end
            if not found then recipesByOutput[outputID][#recipesByOutput[outputID] + 1] = recipe end
        end
    end

    local expanded = {}
    local function AddItem(itemID)
        itemID = tonumber(itemID)
        if not itemID or itemID <= 0 then return end
        relevant[itemID] = true
        if expanded[itemID] then return end
        expanded[itemID] = true

        -- Si un composant est fabriquable via un métier importé, ses
        -- propres ingrédients deviennent également pertinents.
        for _, recipe in ipairs(recipesByOutput[itemID] or {}) do
            for _, reagent in ipairs(recipe.reagents or {}) do
                local choices = reagent.choices or { reagent.itemID }
                for _, choiceID in ipairs(choices) do
                    AddItem(choiceID)
                end
            end
        end
    end

    -- Toutes les recettes importées servent de racines, quel que soit l'onglet actif.
    local rootRecipes, seenRecipes = {}, {}
    for _, profession in pairs(professions) do
        for _, recipe in ipairs((profession and profession.recipes) or {}) do
            local key = tostring(recipe.recipeID or recipe.outputItemID or recipe.name)
            if not seenRecipes[key] then
                seenRecipes[key] = true
                rootRecipes[#rootRecipes + 1] = recipe
            end
        end
    end
    for _, recipe in ipairs(activeRecipes) do
        local key = tostring(recipe.recipeID or recipe.outputItemID or recipe.name)
        if not seenRecipes[key] then
            seenRecipes[key] = true
            rootRecipes[#rootRecipes + 1] = recipe
        end
    end
    for _, recipe in ipairs(rootRecipes) do
        AddItem(recipe.outputItemID)
        for _, reagent in ipairs(recipe.reagents or {}) do
            local choices = reagent.choices or { reagent.itemID }
            for _, choiceID in ipairs(choices) do AddItem(choiceID) end
        end
    end

    return relevant
end

function FLM:CalculateDeals()
    if not self.DB then return {} end


    -- Les recettes de tous les métiers sont prises en compte pour les composants,
    -- même si l'utilisateur consulte actuellement un autre métier.
    local recipesByOutput = {}
    local function AddRecipes(recipes)
        for _, recipe in ipairs(recipes or {}) do
            local id = tonumber(recipe.outputItemID)
            if id then
                recipesByOutput[id] = recipesByOutput[id] or {}
                local found = false
                for _, existing in ipairs(recipesByOutput[id]) do
                    if existing.recipeID == recipe.recipeID and existing.name == recipe.name then
                        found = true
                        break
                    end
                end
                if not found then table.insert(recipesByOutput[id], recipe) end
            end
        end
    end
    for _, profession in pairs(self.DB.professions or {}) do
        AddRecipes(profession and profession.recipes)
    end
    AddRecipes(self.DB.recipes)

    local results = {}
    for _, recipe in ipairs(self.DB.recipes or {}) do
        local outputID = tonumber(recipe.outputItemID)
        local salePrice = outputID and self.DB.prices[outputID]
        local totalCost, complete, missingMaterials = 0, true, 0
        local materialDetails = {}

        for _, reagent in ipairs(recipe.reagents or {}) do
            local choices = reagent.choices or { reagent.itemID }
            local bestChoice, bestChoiceID, bestSource
            for _, choiceID in ipairs(choices) do
                local cost, source = BestItemCostInfo(choiceID, recipesByOutput, { [outputID] = true })
                if cost and (not bestChoice or cost < bestChoice) then
                    bestChoice, bestChoiceID, bestSource = cost, tonumber(choiceID), source
                end
            end

            local quantity = tonumber(reagent.count) or 0
            if not bestChoice then
                complete = false
                missingMaterials = missingMaterials + 1
                materialDetails[#materialDetails + 1] = {
                    itemID = tonumber(reagent.itemID), name = reagent.name,
                    count = quantity, source = "Prix inconnu",
                }
            else
                local itemName = reagent.name
                if bestChoiceID and GetItemInfo then itemName = GetItemInfo(bestChoiceID) or itemName end
                materialDetails[#materialDetails + 1] = {
                    itemID = bestChoiceID or tonumber(reagent.itemID),
                    name = itemName or ("Composant " .. tostring(bestChoiceID or reagent.itemID or "?")),
                    count = quantity, unitCost = bestChoice,
                    totalCost = bestChoice * quantity, source = bestSource,
                }
                totalCost = totalCost + bestChoice * quantity
            end
        end

        if outputID then
            local outputCount = math.max(1, tonumber(recipe.outputCount) or 1)
            local grossSale = salePrice and (salePrice * outputCount) or nil
            local commissionRate = tonumber(self.DB.ahCut) or 0.05
            local commission = grossSale and math.floor(grossSale * commissionRate) or nil
            local netSale = grossSale and (grossSale - commission) or nil

            local duration = tonumber(self.DB.ahDuration) or 8
            local depositRate = duration == 2 and 0.05 or (duration == 24 and 0.60 or 0.20)
            local vendorPrice
            if GetItemInfo then
                local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(outputID)
                vendorPrice = tonumber(sellPrice)
            end
            local depositCost
            if vendorPrice then
                depositCost = math.max(1, math.floor(vendorPrice * depositRate * outputCount))
            end

            local hasCompletePrices = complete and netSale ~= nil
            local profit = hasCompletePrices and (netSale - totalCost) or nil

            table.insert(results, {
                recipeID = recipe.recipeID,
                name = recipe.name or ("Recette " .. tostring(recipe.recipeID)),
                outputItemID = outputID,
                outputCount = outputCount,
                salePriceUpdated = self.DB.priceUpdated and self.DB.priceUpdated[outputID],
                materialCost = complete and totalCost or nil,
                materialDetails = materialDetails,
                partialMaterialCost = totalCost,
                missingMaterials = missingMaterials,
                pricesComplete = hasCompletePrices,
                grossSale = grossSale,
                netSale = netSale,
                commission = commission,
                depositCost = depositCost,
                auctionDuration = duration,
                profit = profit,
                margin = profit and totalCost > 0 and (profit / totalCost) * 100 or nil,
                learned = recipe.learned,
                canSkillUp = recipe.canSkillUp,
                relativeDifficulty = recipe.relativeDifficulty,
            })
        end
    end

    table.sort(results, function(a, b)
        local pa, pb = tonumber(a.profit), tonumber(b.profit)
        if pa == nil then return false end
        if pb == nil then return true end
        return pa > pb
    end)
    self.DB.lastResults = results
    return results
end
