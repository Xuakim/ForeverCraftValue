local ADDON, FLM = ...

local BUTTON_NAME = "ForeverCraftValueMinimapButton"
local ICON = "Interface\\Icons\\INV_Misc_ArmorKit_17"
local button

local function UpdatePosition()
    if not button or not FLM.DB then return end
    local angle = math.rad(tonumber(FLM.DB.minimap.angle) or 220)

    -- Keep the button outside the minimap's masked area and its border.
    local radius = (Minimap:GetWidth() / 2) + 18
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function FadeIn()
    if not button then return end
    button.fadeOut:Stop()
    button:Show()
    button.fadeIn:Stop()
    button.fadeInAlpha:SetFromAlpha(button:GetAlpha())
    button.fadeIn:Play()
end

local function FadeOut()
    if not button then return end
    button.fadeIn:Stop()
    button.fadeOut:Stop()
    button.fadeOutAlpha:SetFromAlpha(button:GetAlpha())
    button.fadeOut:Play()
end

local function UpdateVisibility()
    if not button or not FLM.DB then return end
    if FLM.DB.minimap.hide then
        button.fadeIn:Stop()
        button.fadeOut:Stop()
        button:Hide()
    else
        button:SetAlpha(0)
        button:Show()
        FadeOut()
    end
end

local function UpdateHoverVisibility()
    if not button or not FLM.DB or FLM.DB.minimap.hide then return end

    local overMinimap = Minimap and Minimap.IsMouseOver and Minimap:IsMouseOver()
    local overButton = button.IsMouseOver and button:IsMouseOver()
    if overMinimap or overButton then
        FadeIn()
    else
        FadeOut()
    end
end

local function ScheduleHoverCheck()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, UpdateHoverVisibility)
    else
        UpdateHoverVisibility()
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

    -- UIParent prevents the minimap's circular mask from clipping the outer button.
    button = CreateFrame("Button", BUTTON_NAME, UIParent)
    button:SetSize(32, 32)
    button:SetFrameStrata(Minimap:GetFrameStrata())
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.fadeIn = button:CreateAnimationGroup()
    local fadeInAlpha = button.fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(0.22)
    fadeInAlpha:SetSmoothing("OUT")
    button.fadeInAlpha = fadeInAlpha

    button.fadeOut = button:CreateAnimationGroup()
    local fadeOutAlpha = button.fadeOut:CreateAnimation("Alpha")
    fadeOutAlpha:SetFromAlpha(1)
    fadeOutAlpha:SetToAlpha(0)
    fadeOutAlpha:SetDuration(0.22)
    fadeOutAlpha:SetSmoothing("OUT")
    button.fadeOutAlpha = fadeOutAlpha
    button.fadeOut:SetScript("OnFinished", function()
        if button and button:GetAlpha() <= 0.01 then
            button:Hide()
        end
    end)

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
        if FLM.DB and not FLM.DB.minimap.hide then FadeIn() end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever CraftValue", 0.2, 0.8, 1)
        GameTooltip:AddLine("Clic gauche : ouvrir/fermer", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : actualiser le classement", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ScheduleHoverCheck()
    end)

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
        FadeIn()
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
        ScheduleHoverCheck()
    end)

    if Minimap.HookScript then
        Minimap:HookScript("OnEnter", function()
            if FLM.DB and not FLM.DB.minimap.hide then FadeIn() end
        end)
        Minimap:HookScript("OnLeave", ScheduleHoverCheck)
    end

    UpdatePosition()
    UpdateVisibility()
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    CreateMinimapButton()
end)
