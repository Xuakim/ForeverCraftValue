local ADDON, FLM = ...

local BUTTON_NAME = "ForeverCraftValueMinimapButton"
local ICON = "Interface\\Icons\\INV_Misc_ArmorKit_17"
local button

local function UpdatePosition()
    if not button or not FLM.DB then return end
    local angle = math.rad(tonumber(FLM.DB.minimap.angle) or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateVisibility()
    if not button or not FLM.DB then return end
    if FLM.DB.minimap.hide then
        button:Hide()
    else
        button:Show()
    end
end

function FLM:ToggleMinimapButton()
    if not self.DB then return end
    self.DB.minimap.hide = not self.DB.minimap.hide
    UpdateVisibility()
    self:Print(self.DB.minimap.hide and "Bouton minimap masqué." or "Bouton minimap affiché.")
end

local function CreateMinimapButton()
    if button then return end

    button = CreateFrame("Button", BUTTON_NAME, Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetSize(54, 54)
    overlay:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever CraftValue", 0.2, 0.8, 1)
        GameTooltip:AddLine("Clic gauche : ouvrir/fermer", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : actualiser le classement", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            FLM:RefreshWindow()
            FLM:Print("Classement actualisé.")
        else
            if _G.ForeverCraftValueFrame and _G.ForeverCraftValueFrame:IsShown() then
                _G.ForeverCraftValueFrame:Hide()
            else
                FLM:ShowWindow()
            end
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            local angle = math.atan2(cy - my, cx - mx)
            FLM.DB.minimap.angle = math.deg(angle)
            UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    UpdatePosition()
    UpdateVisibility()
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    CreateMinimapButton()
end)
