local ADDON, FLM = ...

FLM.VERSION = "0.2.5"
FLM.DB = nil

local defaults = {
    ahCut = 0.05,
    prices = {},       -- [itemID] = lowest observed unit buyout (copper)
    recipes = {},      -- imported from the open profession window
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
    print("|cff35d0ffForever Leather Master:|r " .. tostring(message))
end

function FLM:FormatGold(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    return string.format("%dg %02ds %02dc", gold, silver, bronze)
end

function FLM:SetPrice(itemID, copper)
    itemID, copper = tonumber(itemID), tonumber(copper)
    if not itemID or not copper or itemID <= 0 or copper < 0 then
        return false
    end
    self.DB.prices[itemID] = copper
    return true
end

function FLM:Refresh()
    if self.RefreshWindow then self:RefreshWindow() end
end

local function HandleSlash(msg)
    local cmd, a, b = msg:match("^(%S*)%s*(%S*)%s*(%S*)$")
    cmd = (cmd or ""):lower()

    if cmd == "help" then
        FLM:Print("/flm : ouvrir l'interface")
        FLM:Print("Ouvre la fenêtre du Travail du cuir puis clique sur « Importer recettes ».")
        FLM:Print("À l'hôtel des ventes, clique sur « Scanner l'HDV ».")
        FLM:Print("/flm price <itemID> <cuivre> : prix manuel de test")
    elseif cmd == "minimap" then
        if FLM.ToggleMinimapButton then FLM:ToggleMinimapButton() end
    elseif cmd == "price" then
        if FLM:SetPrice(a, b) then
            FLM:Print("Prix enregistré : objet " .. a .. " = " .. FLM:FormatGold(b))
            FLM:Refresh()
        else
            FLM:Print("Usage : /flm price <itemID> <cuivre>")
        end
    else
        FLM:ShowWindow()
    end
end

SLASH_FOREVERLEATHERMASTER1 = "/flm"
SlashCmdList["FOREVERLEATHERMASTER"] = HandleSlash

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        ForeverLeatherMasterDB = ForeverLeatherMasterDB or {}
        CopyDefaults(ForeverLeatherMasterDB, defaults)
        FLM.DB = ForeverLeatherMasterDB
        FLM:Print("v" .. FLM.VERSION .. " chargé. Tape /flm.")
    end
end)
