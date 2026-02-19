local ADDON_NAME = "Turtle_PetHappiness"

local DEFAULTS = {
    point = "CENTER",
    x = 0,
    y = -180,
    width = 220,
    height = 16,
    locked = false,
    value = 100,
}

local DECAY_PER_SECOND = 0.02
local FEED_BOOST = 25

local happinessBarFrame = CreateFrame("Frame", "TurtlePetHappinessFrame", UIParent)
local happinessBar
local happinessBarText

local happinessValue = 100
local stateTarget = 100
local hasPet = false
local elapsedAccumulator = 0
local initialized = false
local lastFeedEventTime = 0
local feedGraceUntil = 0

local function Clamp(value, minVal, maxVal)
    if value < minVal then
        return minVal
    elseif value > maxVal then
        return maxVal
    end
    return value
end

local function BaseValueFromState(state)
    if state == 3 then
        return 83
    elseif state == 2 then
        return 50
    elseif state == 1 then
        return 17
    end
    return nil
end

local function SavePosition()
    local point, _, _, x, y = happinessBarFrame:GetPoint(1)
    TurtlePetHappinessDB.point = point
    TurtlePetHappinessDB.x = x
    TurtlePetHappinessDB.y = y
end

local function ApplyPosition()
    happinessBarFrame:ClearAllPoints()
    happinessBarFrame:SetPoint(TurtlePetHappinessDB.point, UIParent, TurtlePetHappinessDB.point, TurtlePetHappinessDB.x, TurtlePetHappinessDB.y)
end

local function UpdateBarColor()
    if happinessValue >= 67 then
        happinessBar:SetStatusBarColor(0.2, 0.8, 0.2)
    elseif happinessValue >= 34 then
        happinessBar:SetStatusBarColor(0.9, 0.75, 0.2)
    else
        happinessBar:SetStatusBarColor(0.9, 0.2, 0.2)
    end
end

local function UpdateVisual()
    if not happinessBar or not happinessBarText then
        return
    end

    happinessBar:SetValue(happinessValue)
    UpdateBarColor()

    local state = GetPetHappiness and GetPetHappiness() or nil
    local stateText = "No Pet"
    if state == 3 then
        stateText = "Happy"
    elseif state == 2 then
        stateText = "Content"
    elseif state == 1 then
        stateText = "Unhappy"
    end

    happinessBarText:SetText(string.format("Happiness %d%% (%s)", happinessValue, stateText))
end

local function SyncToGameState(forceSnap)
    if not happinessBar or not happinessBarText then
        return
    end

    if not UnitExists("pet") then
        hasPet = false
        happinessBarFrame:Show()
        stateTarget = nil
        UpdateVisual()
        return
    end

    hasPet = true
    happinessBarFrame:Show()

    local state = GetPetHappiness and GetPetHappiness() or nil
    local target = BaseValueFromState(state)
    local now = GetTime and GetTime() or 0

    if target then
        if forceSnap then
            stateTarget = target
            happinessValue = target
        else
            if now < feedGraceUntil and target < happinessValue then
                if not stateTarget or target > stateTarget then
                    stateTarget = target
                end
            else
                stateTarget = target
                happinessValue = (happinessValue * 0.8) + (stateTarget * 0.2)
            end
        end
    end

    happinessValue = Clamp(happinessValue, 0, 100)
    UpdateVisual()
end

local function OnFeedDetected()
    if not hasPet then
        return
    end

    local now = GetTime and GetTime() or 0
    if (now - lastFeedEventTime) < 1.5 then
        return
    end
    lastFeedEventTime = now

    happinessValue = Clamp(happinessValue + FEED_BOOST, 0, 100)
    if not stateTarget or happinessValue > stateTarget then
        stateTarget = happinessValue
    end
    feedGraceUntil = now + 10
    UpdateVisual()
end

local function IsLikelyFeedMessage(msg)
    if not msg then
        return false
    end

    local lower = string.lower(msg)
    if string.find(lower, "feed pet", 1, true) then
        return true
    end

    if string.find(lower, "pet begins eating", 1, true) then
        return true
    end

    return false
end

local function ToggleLock(locked)
    TurtlePetHappinessDB.locked = locked
    happinessBarFrame:EnableMouse(not locked)

    if locked then
        happinessBarText:SetTextColor(1, 1, 1)
    else
        happinessBarText:SetTextColor(0.8, 0.95, 1)
    end
end

local function InitializeAddon()
    if initialized then
        return
    end

    if not TurtlePetHappinessDB then
        TurtlePetHappinessDB = {}
    end

    for key, value in pairs(DEFAULTS) do
        if TurtlePetHappinessDB[key] == nil then
            TurtlePetHappinessDB[key] = value
        end
    end

    happinessBarFrame:SetWidth(TurtlePetHappinessDB.width)
    happinessBarFrame:SetHeight(TurtlePetHappinessDB.height + 2)
    happinessBarFrame:SetFrameStrata("MEDIUM")

    happinessBar = CreateFrame("StatusBar", nil, happinessBarFrame)
    happinessBar:SetParent(happinessBarFrame)
    happinessBar:SetPoint("TOPLEFT", happinessBarFrame, "TOPLEFT", 3, -3)
    happinessBar:SetPoint("TOPRIGHT", happinessBarFrame, "TOPRIGHT", -4, 0)
    happinessBar:SetHeight(12)
    happinessBar:SetMinMaxValues(0, 100)
    happinessBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    happinessBar.bg = happinessBar:CreateTexture(nil, "BACKGROUND")
    happinessBar.bg:SetAllPoints(happinessBar)
    happinessBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    happinessBar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

    happinessBarText = happinessBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    happinessBarText:SetParent(happinessBar)
    happinessBarText:SetPoint("TOPLEFT", happinessBar, "TOPLEFT", 2, -1)

    happinessBarFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    happinessBarFrame:SetBackdropColor(0, 0, 0, 0.5)

    happinessBarFrame:RegisterForDrag("LeftButton")
    happinessBarFrame:SetMovable(true)
    happinessBarFrame:SetClampedToScreen(true)
    happinessBarFrame:SetScript("OnDragStart", function()
        if not TurtlePetHappinessDB.locked then
            happinessBarFrame:StartMoving()
        end
    end)
    happinessBarFrame:SetScript("OnDragStop", function()
        happinessBarFrame:StopMovingOrSizing()
        SavePosition()
    end)

    ApplyPosition()
    happinessBarFrame:Show()
    happinessValue = Clamp(TurtlePetHappinessDB.value or 100, 0, 100)
    ToggleLock(TurtlePetHappinessDB.locked)

    SLASH_TURTLEPETHAPPINESS1 = "/tph"
    SlashCmdList.TURTLEPETHAPPINESS = function(msg)
        local input = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))

        if input == "lock" then
            ToggleLock(true)
            print("Turtle Pet Happiness: locked")
        elseif input == "unlock" then
            ToggleLock(false)
            print("Turtle Pet Happiness: unlocked")
        elseif input == "reset" then
            TurtlePetHappinessDB.point = DEFAULTS.point
            TurtlePetHappinessDB.x = DEFAULTS.x
            TurtlePetHappinessDB.y = DEFAULTS.y
            ApplyPosition()
            print("Turtle Pet Happiness: position reset")
        elseif input == "show" then
            TurtlePetHappinessDB.point = DEFAULTS.point
            TurtlePetHappinessDB.x = DEFAULTS.x
            TurtlePetHappinessDB.y = DEFAULTS.y
            ApplyPosition()
            happinessBarFrame:Show()
            print("Turtle Pet Happiness: shown at center")
        else
            print("Turtle Pet Happiness commands: /tph lock, /tph unlock, /tph reset, /tph show")
        end
    end

    initialized = true
    print("Turtle Pet Happiness loaded. Type /tph show if the frame is off-screen.")
    SyncToGameState(true)
end

happinessBarFrame:SetScript("OnEvent", function(self, evt, a1)
    evt = evt or event
    a1 = a1 or arg1

    if evt == "ADDON_LOADED" then
        if a1 == ADDON_NAME or a1 == "Turtle Pet Happiness" then
            InitializeAddon()
        end
    elseif evt == "PLAYER_LOGIN" then
        InitializeAddon()
        SyncToGameState(true)
    elseif evt == "PLAYER_ENTERING_WORLD" then
        SyncToGameState(false)
    elseif evt == "UNIT_HAPPINESS" then
        SyncToGameState(false)
    elseif evt == "UNIT_PET" and a1 == "player" then
        SyncToGameState(true)
    elseif evt == "PET_BAR_UPDATE" or evt == "PET_UI_UPDATE" then
        SyncToGameState(false)
    elseif evt == "CHAT_MSG_SPELL_SELF_BUFF" or evt == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        if IsLikelyFeedMessage(a1) then
            OnFeedDetected()
        end
    end
end)

happinessBarFrame:SetScript("OnUpdate", function(_, elapsed)
    elapsed = elapsed or arg1 or 0

    if not hasPet then
        return
    end

    elapsedAccumulator = elapsedAccumulator + elapsed
    if elapsedAccumulator < 0.1 then
        return
    end

    local delta = elapsedAccumulator
    elapsedAccumulator = 0

    happinessValue = happinessValue - (DECAY_PER_SECOND * delta)

    if stateTarget then
        happinessValue = (happinessValue * 0.95) + (stateTarget * 0.05)
    end

    happinessValue = Clamp(happinessValue, 0, 100)
    UpdateVisual()
end)

happinessBarFrame:RegisterEvent("ADDON_LOADED")
happinessBarFrame:RegisterEvent("PLAYER_LOGIN")
happinessBarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
happinessBarFrame:RegisterEvent("UNIT_HAPPINESS")
happinessBarFrame:RegisterEvent("UNIT_PET")
happinessBarFrame:RegisterEvent("PET_BAR_UPDATE")
happinessBarFrame:RegisterEvent("PET_UI_UPDATE")
happinessBarFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
happinessBarFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")

happinessBarFrame:SetScript("OnHide", function()
    if TurtlePetHappinessDB then
        TurtlePetHappinessDB.value = happinessValue
    end
end)
