local ADDON, FLM = ...

FLM.VERSION = "1.1.7"
FLM.DB = nil

local defaults = {
    ahCut = 0.05, -- Commission faction WoW Forever
    ahDuration = 8, -- Durée de mise en vente en heures
    prices = {},       -- [itemID] = observed reference unit buyout (copper)
    priceHistory = {}, -- [itemID] = { { time = timestamp, price = copper }, ... }
    priceUpdated = {}, -- [itemID] = timestamp of latest auction observation
    recipes = {},      -- active profession recipes
    professions = {},  -- [professionName] = { recipes = {}, lastImport = timestamp }
    activeProfession = nil,
    lastScan = 0,
    lastScanCount = 0,
    lastResults = {},
    minimap = { angle = 220, hide = false },
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function FLM:Print(message)
    print("|cff35d0ffForever CraftValue:|r " .. tostring(message))
end

function FLM:FormatGold(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    return string.format("%dg %02ds %02dc", gold, silver, bronze)
end

-- Affichage compact avec les icônes officielles or / argent / cuivre.
function FLM:FormatMoneyIcons(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    local parts = {}

    local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t"
    local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:0:0|t"
    local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:0:0|t"

    if gold > 0 then parts[#parts + 1] = gold .. goldIcon end
    if silver > 0 then parts[#parts + 1] = silver .. silverIcon end
    if bronze > 0 or #parts == 0 then parts[#parts + 1] = bronze .. copperIcon end

    return table.concat(parts, " ")
end


function FLM:FormatPriceAge(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 then return "Âge inconnu" end
    local age = math.max(0, time() - timestamp)
    if age < 60 then return "À l'instant" end
    if age < 3600 then return "MAJ il y a " .. math.floor(age / 60) .. " min" end
    if age < 86400 then return "MAJ il y a " .. math.floor(age / 3600) .. " h" end
    return "MAJ il y a " .. math.floor(age / 86400) .. " j"
end

function FLM:SetAuctionDuration(hours)
    hours = tonumber(hours)
    if hours ~= 2 and hours ~= 8 and hours ~= 24 then return false end
    self.DB.ahDuration = hours
    self:Refresh()
    return true
end

function FLM:SetPrice(itemID, copper)
    itemID, copper = tonumber(itemID), tonumber(copper)
    if not itemID or not copper or itemID <= 0 or copper < 0 then
        return false
    end
    self.DB.prices[itemID] = copper
    self.DB.priceUpdated = self.DB.priceUpdated or {}
    self.DB.priceUpdated[itemID] = time()
    return true
end

function FLM:Refresh()
    if self.RefreshWindow then self:RefreshWindow() end
end

local function HandleSlash(msg)
    local cmd, a, b = msg:match("^(%S*)%s*(%S*)%s*(%S*)$")
    cmd = (cmd or ""):lower()

    if cmd == "help" then
        FLM:Print("/fcv : ouvrir l'interface (/flm reste compatible)")
        FLM:Print("Ouvre la fenêtre du métier souhaité puis clique sur « Importer recettes ».")
        FLM:Print("À l'hôtel des ventes, clique sur « Scanner l'HDV ».")
        FLM:Print("/flm price <itemID> <cuivre> : prix manuel de test")
    elseif cmd == "minimap" then
        if FLM.ToggleMinimapButton then FLM:ToggleMinimapButton() end
    elseif cmd == "price" then
        if FLM:SetPrice(a, b) then
            FLM:Print("Prix enregistré : objet " .. a .. " = " .. FLM:FormatGold(b))
            FLM:Refresh()
        else
            FLM:Print("Usage : /fcv price <itemID> <cuivre>")
        end
    else
        FLM:ShowWindow()
    end
end

SLASH_FOREVERLEATHERMASTER1 = "/flm"
SLASH_FOREVERCRAFTVALUE1 = "/fcv"
SlashCmdList["FOREVERLEATHERMASTER"] = HandleSlash
SlashCmdList["FOREVERCRAFTVALUE"] = HandleSlash

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        ForeverLeatherMasterDB = ForeverLeatherMasterDB or {}
        CopyDefaults(ForeverLeatherMasterDB, defaults)
        FLM.DB = ForeverLeatherMasterDB
        FLM.DB.merchantPrices = nil
        FLM.DB.merchantPriceUpdated = nil
        FLM.DB.merchantVisits = nil
        FLM:InitializeProfessionData()
        FLM:Print("v" .. FLM.VERSION .. " chargé. Tape /fcv.")
    end
end)
