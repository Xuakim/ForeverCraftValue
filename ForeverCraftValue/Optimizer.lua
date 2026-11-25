local ADDON, FLM = ...

local function BestItemCost(itemID, prices, recipesByOutput, visiting)
    local best = prices[itemID]
    local alternatives = recipesByOutput[itemID]

    if alternatives and not visiting[itemID] then
        visiting[itemID] = true

        for _, recipe in ipairs(alternatives) do
            local cost, valid = 0, true

            for _, reagent in ipairs(recipe.reagents or {}) do
                local choices = reagent.choices or { reagent.itemID }
                local bestChoice
                for _, choiceID in ipairs(choices) do
                    local choiceCost = BestItemCost(choiceID, prices, recipesByOutput, visiting)
                    if choiceCost and (not bestChoice or choiceCost < bestChoice) then
                        bestChoice = choiceCost
                    end
                end

                if not bestChoice then
                    valid = false
                    break
                end
                cost = cost + bestChoice * (tonumber(reagent.count) or 0)
            end

            if valid then
                local outputCount = math.max(1, tonumber(recipe.outputCount) or 1)
                local unitCost = cost / outputCount
                if not best or unitCost < best then best = unitCost end
            end
        end

        visiting[itemID] = nil
    end

    return best
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

    for _, recipe in ipairs(activeRecipes) do
        AddItem(recipe.outputItemID)
        for _, reagent in ipairs(recipe.reagents or {}) do
            local choices = reagent.choices or { reagent.itemID }
            for _, choiceID in ipairs(choices) do
                AddItem(choiceID)
            end
        end
    end

    return relevant
end

function FLM:CalculateDeals()
    if not self.DB then return {} end

    local recipesByOutput = {}
    for _, recipe in ipairs(self.DB.recipes or {}) do
        local id = tonumber(recipe.outputItemID)
        if id then
            recipesByOutput[id] = recipesByOutput[id] or {}
            table.insert(recipesByOutput[id], recipe)
        end
    end

    local results = {}
    for _, recipe in ipairs(self.DB.recipes or {}) do
        local outputID = tonumber(recipe.outputItemID)
        local salePrice = outputID and self.DB.prices[outputID]
        local totalCost, complete, missingMaterials = 0, true, 0

        for _, reagent in ipairs(recipe.reagents or {}) do
            local choices = reagent.choices or { reagent.itemID }
            local bestChoice
            for _, choiceID in ipairs(choices) do
                local cost = BestItemCost(choiceID, self.DB.prices, recipesByOutput, { [outputID] = true })
                if cost and (not bestChoice or cost < bestChoice) then bestChoice = cost end
            end

            if not bestChoice then
                complete = false
                missingMaterials = missingMaterials + 1
            else
                totalCost = totalCost + bestChoice * (tonumber(reagent.count) or 0)
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
