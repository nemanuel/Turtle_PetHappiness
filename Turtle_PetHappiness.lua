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

local DECAY_PER_SECOND = 0.06
local FEED_BOOST = 25

local mainframe = CreateFrame("Frame", "TurtlePetHappinessFrame", UIParent)
local happinessBarFrame
local happinessBar
local happinessBarText
local petXpBarFrame
local petXpBar
local petXpBarText
local petInfoText
local loyaltyInfoText

local happinessValue = 100
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

local function StateBandFromState(state)
    if state == 3 then
        return 67, 100
    elseif state == 2 then
        return 34, 66
    elseif state == 1 then
        return 0, 33
    end
    return nil, nil
end

local function SavePosition()
    local point, _, _, x, y = mainframe:GetPoint(1)
    TurtlePetHappinessDB.point = point
    TurtlePetHappinessDB.x = x
    TurtlePetHappinessDB.y = y
end

local function ApplyPosition()
    mainframe:ClearAllPoints()
    mainframe:SetPoint(TurtlePetHappinessDB.point, UIParent, TurtlePetHappinessDB.point, TurtlePetHappinessDB.x, TurtlePetHappinessDB.y)
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
    if not happinessBar or not happinessBarText or not petXpBar or not petXpBarText or not petInfoText or not loyaltyInfoText then
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

    if UnitExists("pet") then
        local petLevel = UnitLevel("pet")
        local petFamily = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        local petXP, petXPMax = nil, nil
        local loyaltyLevelRaw, loyaltyNameRaw = nil, nil
        local loyaltyLevel = nil
        local loyaltyName = nil

        if GetPetLoyalty then
            loyaltyLevelRaw, loyaltyNameRaw = GetPetLoyalty()
        end

        if GetPetExperience then
            petXP, petXPMax = GetPetExperience()
        end

        if type(loyaltyLevelRaw) == "number" then
            loyaltyLevel = loyaltyLevelRaw
            loyaltyName = loyaltyNameRaw
        elseif type(loyaltyNameRaw) == "number" then
            loyaltyLevel = loyaltyNameRaw
            loyaltyName = loyaltyLevelRaw
        else
            loyaltyLevel = tonumber(loyaltyLevelRaw) or tonumber(loyaltyNameRaw)
            loyaltyName = loyaltyNameRaw or loyaltyLevelRaw
        end

        if loyaltyName and type(loyaltyName) ~= "string" then
            loyaltyName = tostring(loyaltyName)
        end

        if not petFamily or petFamily == "" then
            petFamily = "Unknown"
        end

        if petLevel and petLevel > 0 then
            petInfoText:SetText(string.format("Level %d %s", petLevel, petFamily))
        else
            petInfoText:SetText(string.format("Level ? %s", petFamily))
        end

        if loyaltyLevel and loyaltyName and loyaltyName ~= "" then
            loyaltyInfoText:SetText(string.format("(Loyalty Level %d) %s", loyaltyLevel, loyaltyName))
        elseif loyaltyLevel then
            loyaltyInfoText:SetText(string.format("(Loyalty Level %d)", loyaltyLevel))
        elseif loyaltyName and loyaltyName ~= "" then
            loyaltyInfoText:SetText(string.format("%s", loyaltyName))
        else
            loyaltyInfoText:SetText("(Loyalty Unknown)")
        end

        if petXP and petXPMax and petXPMax > 0 then
            petXpBar:SetMinMaxValues(0, petXPMax)
            petXpBar:SetValue(petXP)
            petXpBarText:SetText(string.format("XP %d/%d", petXP, petXPMax))
        else
            petXpBar:SetMinMaxValues(0, 100)
            petXpBar:SetValue(0)
            petXpBarText:SetText("XP N/A")
        end
    else
        petInfoText:SetText("No active pet")
        loyaltyInfoText:SetText("")
        petXpBar:SetMinMaxValues(0, 100)
        petXpBar:SetValue(0)
        petXpBarText:SetText("XP N/A")
    end

    happinessBarText:SetText(string.format("Happiness %d%% (%s)", happinessValue, stateText))
end

local function SyncToGameState(forceSnap)
    if not happinessBar or not happinessBarText then
        return
    end

    hasPet = UnitExists("pet") and true or false
    mainframe:Show()

    if not hasPet then
        UpdateVisual()
        return
    end

    local state = GetPetHappiness and GetPetHappiness() or nil
    local minBand, maxBand = StateBandFromState(state)

    if not (minBand and maxBand) then
        happinessValue = Clamp(happinessValue, 0, 100)
        UpdateVisual()
        return
    end

    if forceSnap then
        happinessValue = (minBand + maxBand) / 2
    else
        local now = GetTime and GetTime() or 0
        if now < feedGraceUntil then
            if happinessValue < minBand then
                happinessValue = minBand
            end
        elseif happinessValue < minBand then
            happinessValue = (happinessValue * 0.8) + (minBand * 0.4)
        elseif happinessValue > maxBand then
            happinessValue = (happinessValue * 0.85) + (maxBand * 0.15)
        end
    end

    happinessValue = Clamp(happinessValue, 0, 100)
    UpdateVisual()
end

local function OnFeedDetected()
    local now = GetTime and GetTime() or 0
    if not hasPet or (now - lastFeedEventTime) < 1.5 then
        return
    end

    lastFeedEventTime = now
    happinessValue = Clamp(happinessValue + FEED_BOOST, 0, 100)
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
    mainframe:EnableMouse(not locked)

    if locked then
        happinessBarText:SetTextColor(1, 1, 1)
        if petXpBarText then
            petXpBarText:SetTextColor(1, 1, 1)
        end
        if petInfoText then
            petInfoText:SetTextColor(1, 1, 1)
        end
        if loyaltyInfoText then
            loyaltyInfoText:SetTextColor(1, 1, 1)
        end
    else
        happinessBarText:SetTextColor(0.8, 0.95, 1)
        if petXpBarText then
            petXpBarText:SetTextColor(0.8, 0.95, 1)
        end
        if petInfoText then
            petInfoText:SetTextColor(0.8, 0.95, 1)
        end
        if loyaltyInfoText then
            loyaltyInfoText:SetTextColor(0.8, 0.95, 1)
        end
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

    mainframe:SetWidth(TurtlePetHappinessDB.width)
    mainframe:SetHeight(TurtlePetHappinessDB.height + 65)
    mainframe:SetFrameStrata("MEDIUM")

    happinessBarFrame = CreateFrame("Frame", nil, mainframe)
    happinessBarFrame:SetParent(mainframe)
    happinessBarFrame:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 4, -34)
    happinessBarFrame:SetWidth(TurtlePetHappinessDB.width - 8)
    happinessBarFrame:SetHeight(TurtlePetHappinessDB.height + 4)

    happinessBarFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    happinessBarFrame:SetBackdropColor(0, 0, 0, 0.5)

    happinessBar = CreateFrame("StatusBar", nil, happinessBarFrame)
    happinessBar:SetParent(happinessBarFrame)
    happinessBar:SetPoint("TOPLEFT", happinessBarFrame, "TOPLEFT", 3, -4)
    happinessBar:SetPoint("TOPRIGHT", happinessBarFrame, "TOPRIGHT", -4, 0)
    happinessBar:SetHeight(13)
    happinessBar:SetMinMaxValues(0, 100)
    happinessBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    happinessBar.bg = happinessBar:CreateTexture(nil, "BACKGROUND")
    happinessBar.bg:SetAllPoints(happinessBar)
    happinessBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    happinessBar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

    happinessBarText = happinessBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    happinessBarText:SetParent(happinessBar)
    happinessBarText:SetPoint("LEFT", happinessBar, "LEFT", 2, 0)
    happinessBarText:SetJustifyH("CENTER")

    petXpBarFrame = CreateFrame("Frame", nil, mainframe)
    petXpBarFrame:SetParent(mainframe)
    petXpBarFrame:SetPoint("TOPLEFT", happinessBarFrame, "BOTTOMLEFT", 0, -2)
    petXpBarFrame:SetWidth(TurtlePetHappinessDB.width - 8)
    petXpBarFrame:SetHeight(TurtlePetHappinessDB.height + 4)

    petXpBarFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    petXpBarFrame:SetBackdropColor(0, 0, 0, 0.5)

    petXpBar = CreateFrame("StatusBar", nil, petXpBarFrame)
    petXpBar:SetParent(petXpBarFrame)
    petXpBar:SetPoint("TOPLEFT", petXpBarFrame, "TOPLEFT", 3, -4)
    petXpBar:SetPoint("TOPRIGHT", petXpBarFrame, "TOPRIGHT", -4, 0)
    petXpBar:SetHeight(13)
    petXpBar:SetMinMaxValues(0, 100)
    petXpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    petXpBar:SetStatusBarColor(0.25, 0.45, 0.9)

    petXpBar.bg = petXpBar:CreateTexture(nil, "BACKGROUND")
    petXpBar.bg:SetAllPoints(petXpBar)
    petXpBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    petXpBar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

    petXpBarText = petXpBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petXpBarText:SetParent(petXpBar)
    petXpBarText:SetPoint("LEFT", petXpBar, "LEFT", 2, 0)
    petXpBarText:SetJustifyH("CENTER")
    petXpBarText:SetText("XP N/A")

    petInfoText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petInfoText:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 6, -6)
    petInfoText:SetJustifyH("LEFT")
    petInfoText:SetText("No active pet")

    loyaltyInfoText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loyaltyInfoText:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 5, -18)
    loyaltyInfoText:SetJustifyH("CENTER")
    loyaltyInfoText:SetText("")

    mainframe:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    mainframe:SetBackdropColor(0, 0, 0, 0.5)

    mainframe:RegisterForDrag("LeftButton")
    mainframe:SetMovable(true)
    mainframe:SetClampedToScreen(true)
    mainframe:SetScript("OnDragStart", function()
        if not TurtlePetHappinessDB.locked then
            mainframe:StartMoving()
        end
    end)
    mainframe:SetScript("OnDragStop", function()
        mainframe:StopMovingOrSizing()
        SavePosition()
    end)

    ApplyPosition()
    mainframe:Show()
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
            mainframe:Show()
            print("Turtle Pet Happiness: shown at center")
        else
            print("Turtle Pet Happiness commands: /tph lock, /tph unlock, /tph reset, /tph show")
        end
    end

    initialized = true
    print("Turtle Pet Happiness loaded. Type /tph show if the frame is off-screen.")
    SyncToGameState(true)
end

mainframe:SetScript("OnEvent", function(self, evt, a1)
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

mainframe:SetScript("OnUpdate", function(_, elapsed)
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

    happinessValue = Clamp(happinessValue, 0, 100)
    UpdateVisual()
end)

mainframe:RegisterEvent("ADDON_LOADED")
mainframe:RegisterEvent("PLAYER_LOGIN")
mainframe:RegisterEvent("PLAYER_ENTERING_WORLD")
mainframe:RegisterEvent("UNIT_HAPPINESS")
mainframe:RegisterEvent("UNIT_PET")
mainframe:RegisterEvent("PET_BAR_UPDATE")
mainframe:RegisterEvent("PET_UI_UPDATE")
mainframe:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
mainframe:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")

mainframe:SetScript("OnHide", function()
    if TurtlePetHappinessDB then
        TurtlePetHappinessDB.value = happinessValue
    end
end)
