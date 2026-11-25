local ADDON, FLM = ...

local BUTTON_NAME = "ForeverCraftValueMinimapButton"
local ICON = "Interface\\AddOns\\ForeverCraftValue\\ForeverCraftValueIcon.tga"
local button

-- Same positioning model as Questie's LibDBIcon: a small radius outside the minimap edge.
local function UpdatePosition()
    if not button or not FLM.DB then return end

    local angle = math.rad(tonumber(FLM.DB.minimap.angle) or 220)
    local radius = 5
    local width = Minimap:GetWidth() / 2 + radius
    local height = Minimap:GetHeight() / 2 + radius
    local x = math.cos(angle) * width
    local y = math.sin(angle) * height

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function ShowButtonImmediately()
    if not button or not FLM.DB or FLM.DB.minimap.hide then return end
    button.fadeOut:Stop()
    button:SetAlpha(1)
    button:Show()
end

local function FadeButtonOut()
    if not button or not FLM.DB or FLM.DB.minimap.hide then return end
    button.fadeOut:Play()
end

local function UpdateVisibility()
    if not button or not FLM.DB then return end

    button.fadeOut:Stop()
    if FLM.DB.minimap.hide then
        button:Hide()
    else
        button:SetAlpha(0)
        button:Show()
        -- The button stays hidden until the minimap is entered.
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

    -- LibDBIcon/Questie parents its button to Minimap and anchors it just beyond its edge.
    button = CreateFrame("Button", BUTTON_NAME, Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
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

    -- Match LibDBIcon's fade: one-second grace period, then a 0.2s fade.
    button.fadeOut = button:CreateAnimationGroup()
    local fade = button.fadeOut:CreateAnimation("Alpha")
    fade:SetOrder(1)
    fade:SetDuration(0.2)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(1)
    button.fadeOut:SetToFinalAlpha(true)
    button.fadeOut:SetScript("OnFinished", function()
        if button and button:GetAlpha() <= 0.01 then
            button:Hide()
        end
    end)

    button:SetScript("OnEnter", function(self)
        ShowButtonImmediately()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever CraftValue", 0.2, 0.8, 1)
        GameTooltip:AddLine("Clic gauche : ouvrir/fermer", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : actualiser le classement", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        FadeButtonOut()
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

    button:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            FLM.DB.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
            UpdatePosition()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self.fadeOut:Stop()
        self:SetAlpha(1)
        self:LockHighlight()
        self.isDragging = true
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.isDragging = false
        self:UnlockHighlight()
        FadeButtonOut()
        self:SetScript("OnUpdate", function(frame)
            if frame.isDragging then
                local mx, my = Minimap:GetCenter()
                local scale = Minimap:GetEffectiveScale()
                local cx, cy = GetCursorPosition()
                cx, cy = cx / scale, cy / scale
                FLM.DB.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
                UpdatePosition()
            end
        end)
    end)

    Minimap:HookScript("OnEnter", function()
        if button and not (FLM.DB and FLM.DB.minimap.hide) then
            ShowButtonImmediately()
        end
    end)

    Minimap:HookScript("OnLeave", function()
        if button and not (FLM.DB and FLM.DB.minimap.hide) and not button.isDragging then
            FadeButtonOut()
        end
    end)

    UpdatePosition()
    UpdateVisibility()
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    CreateMinimapButton()
end)
