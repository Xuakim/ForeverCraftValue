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
        local totalCost, complete = 0, true

        for _, reagent in ipairs(recipe.reagents or {}) do
            local choices = reagent.choices or { reagent.itemID }
            local bestChoice
            for _, choiceID in ipairs(choices) do
                local cost = BestItemCost(choiceID, self.DB.prices, recipesByOutput, { [outputID] = true })
                if cost and (not bestChoice or cost < bestChoice) then bestChoice = cost end
            end

            if not bestChoice then
                complete = false
                break
            end
            totalCost = totalCost + bestChoice * (tonumber(reagent.count) or 0)
        end

        if complete and salePrice and outputID then
            local outputCount = math.max(1, tonumber(recipe.outputCount) or 1)
            local grossSale = salePrice * outputCount
            local commissionRate = tonumber(self.DB.ahCut) or 0.05
            local commission = math.floor(grossSale * commissionRate)
            local netSale = grossSale - commission

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

            -- Le dépôt est rendu en cas de vente : il n'est pas soustrait du bénéfice.
            local profit = netSale - totalCost

            table.insert(results, {
                recipeID = recipe.recipeID,
                name = recipe.name or ("Recette " .. tostring(recipe.recipeID)),
                outputItemID = outputID,
                outputCount = outputCount,
                salePriceUpdated = self.DB.priceUpdated and self.DB.priceUpdated[outputID],
                materialCost = totalCost,
                grossSale = grossSale,
                netSale = netSale,
                commission = commission,
                depositCost = depositCost,
                auctionDuration = duration,
                profit = profit,
                margin = totalCost > 0 and (profit / totalCost) * 100 or 0,
                learned = recipe.learned,
            })
        end
    end

    table.sort(results, function(a, b) return a.profit > b.profit end)
    self.DB.lastResults = results
    return results
end
