local ADDON_NAME = "Turtle_PetHappiness"
local Addon = TurtlePetHappiness or {}
TurtlePetHappiness = Addon

local DEFAULTS = Addon.DEFAULTS
if type(DEFAULTS) ~= "table" then
    DEFAULTS = {
        point = "CENTER",
        x = 0,
        y = -180,
        width = 220,
        height = 16,
        locked = false,
        hidden = false,
        value = 100
    }
    Addon.DEFAULTS = DEFAULTS
end

local Clamp = Addon.Clamp
if type(Clamp) ~= "function" then
    Clamp = function(value, minVal, maxVal)
        if value < minVal then
            return minVal
        elseif value > maxVal then
            return maxVal
        end
        return value
    end
    Addon.Clamp = Clamp
end

local GetPetDietTooltipText = Addon.GetPetDietTooltipText
if type(GetPetDietTooltipText) ~= "function" then
    GetPetDietTooltipText = function()
        if not UnitExists("pet") then
            return "No active pet"
        end
        return "Unknown"
    end
    Addon.GetPetDietTooltipText = GetPetDietTooltipText
end

local mainframe = CreateFrame("Frame", "TurtlePetHappinessFrame", UIParent)
local happinessBarFrame
local happinessBar
local happinessBarText
local petXpBarFrame
local petXpBar
local petXpBarText
local petInfoText
local loyaltyInfoText
local petTrainingPointsLabelText
local petTrainingPointsText
local petDietIconFrame
local petDietIconTexture
local helpIconFrame
local helpIconTexture

local happinessValue = 0
local hasPet = false
local initialized = false
local db
local backupDb

local function GetCharacterKey()
    local playerName = UnitName and UnitName("player") or nil
    if not playerName or playerName == "" then
        return nil
    end

    local realmName = GetRealmName and GetRealmName() or "UnknownRealm"
    return realmName .. ":" .. playerName
end

local function SyncBackupDb()
    if not db or not backupDb then
        return
    end

    for key, _ in pairs(DEFAULTS) do
        backupDb[key] = db[key]
    end
end

local function SavePosition()
    local point, _, _, x, y = mainframe:GetPoint(1)
    db.point = point
    db.x = x
    db.y = y
    SyncBackupDb()
end

local function ApplyPosition()
    mainframe:ClearAllPoints()
    mainframe:SetPoint(db.point, UIParent, db.point, db.x, db.y)
end

local function UpdateBarColor()
    if happinessValue == 3 then
        happinessBar:SetStatusBarColor(0.2, 0.8, 0.2)
    elseif happinessValue == 2 then
        happinessBar:SetStatusBarColor(0.9, 0.75, 0.2)
    elseif happinessValue == 1 then
        happinessBar:SetStatusBarColor(0.9, 0.2, 0.2)
    else
        happinessBar:SetStatusBarColor(0.4, 0.4, 0.4)
    end
end

local function UpdateVisual()
    if not happinessBar or not happinessBarText or not petXpBar or not petXpBarText or not petInfoText or
        not loyaltyInfoText or not petTrainingPointsLabelText or not petTrainingPointsText then
        return
    end

    happinessBar:SetValue(happinessValue)
    UpdateBarColor()

    if petDietIconFrame then
        if UnitExists("pet") then
            petDietIconFrame:Show()
        else
            petDietIconFrame:Hide()
        end
    end

    local state = happinessValue
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
        local playerLevel = UnitLevel("player")
        local petFamily = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        local petName = UnitName and UnitName("pet") or nil
        local petXP, petXPMax = nil, nil
        local petTrainingPoints = nil
        local loyaltyLevelRaw, loyaltyNameRaw = nil, nil
        local loyaltyLevel = nil
        local loyaltyName = nil

        if GetPetLoyalty then
            loyaltyLevelRaw, loyaltyNameRaw = GetPetLoyalty()
        end

        if GetPetExperience then
            petXP, petXPMax = GetPetExperience()
        end

        if GetPetTrainingPoints then
            local petTrainingPointsPrimary, petTrainingPointsSecondary = GetPetTrainingPoints()
            local primaryNumber = tonumber(petTrainingPointsPrimary)
            local secondaryNumber = tonumber(petTrainingPointsSecondary)

            if type(primaryNumber) == "number" and primaryNumber < 0 then
                petTrainingPoints = primaryNumber
            elseif type(secondaryNumber) == "number" and secondaryNumber < 0 then
                petTrainingPoints = secondaryNumber
            elseif type(primaryNumber) == "number" and type(secondaryNumber) == "number" and
                primaryNumber == 0 and secondaryNumber > 0 then
                petTrainingPoints = -secondaryNumber
            elseif type(primaryNumber) == "number" then
                petTrainingPoints = primaryNumber
            elseif type(secondaryNumber) == "number" then
                petTrainingPoints = secondaryNumber
            end
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

        local petNameSuffix = ""
        local hasCustomName = false
        if petName and petName ~= "" then
            local petNameLower = string.lower(petName)
            local isUnknownName = (petNameLower == "unknown")
            if not isUnknownName then
                if petFamily and petFamily ~= "" then
                    hasCustomName = petNameLower ~= string.lower(petFamily)
                else
                    hasCustomName = true
                end
            else
                hasCustomName = false
            end
        end

        if hasCustomName then
            petNameSuffix = string.format(" (%s)", petName)
        end

        if petLevel and petLevel > 0 then
            petInfoText:SetText(string.format("Level %d %s%s", petLevel, petFamily, petNameSuffix))
        else
            petInfoText:SetText(string.format("Level ? %s%s", petFamily, petNameSuffix))
        end

        if loyaltyLevel and loyaltyName and loyaltyName ~= "" then
            loyaltyInfoText:SetText(string.format("Loyalty Level %d (%s)", loyaltyLevel, loyaltyName))
        elseif loyaltyLevel then
            loyaltyInfoText:SetText(string.format("Loyalty Level %d", loyaltyLevel))
        elseif loyaltyName and loyaltyName ~= "" then
            loyaltyInfoText:SetText(string.format("%s", loyaltyName))
        else
            loyaltyInfoText:SetText("(Loyalty Unknown)")
        end

        if type(petTrainingPoints) == "number" then
            petTrainingPointsLabelText:SetText("TP")
            petTrainingPointsLabelText:SetTextColor(1, 1, 1)
            petTrainingPointsText:SetText(string.format("%d", petTrainingPoints))
            if petTrainingPoints < 0 then
                petTrainingPointsText:SetTextColor(1, 0.2, 0.2)
            elseif petTrainingPoints == 0 then
                petTrainingPointsText:SetTextColor(1, 1, 1)
            else
                petTrainingPointsText:SetTextColor(0.2, 0.9, 0.2)
            end
        else
            petTrainingPointsLabelText:SetText("TP")
            petTrainingPointsLabelText:SetTextColor(1, 1, 1)
            petTrainingPointsText:SetText("N/A")
            petTrainingPointsText:SetTextColor(1, 1, 1)
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

        if type(petLevel) == "number" and type(playerLevel) == "number" and petLevel == playerLevel then
            petXpBarText:SetText("Max Level")
        end
    else
        petInfoText:SetText("No active pet")
        loyaltyInfoText:SetText("")
        petTrainingPointsLabelText:SetText("")
        petTrainingPointsText:SetText("")
        petXpBar:SetMinMaxValues(0, 100)
        petXpBar:SetValue(0)
        petXpBarText:SetText("XP N/A")
    end

    if state == 1 or state == 2 or state == 3 then
        happinessBarText:SetText(string.format("Happiness (%s)", stateText))
    else
        happinessBarText:SetText("Happiness N/A")
    end
end

local function SyncToGameState(forceSnap)
    if not happinessBar or not happinessBarText then
        return
    end

    hasPet = UnitExists("pet") and true or false
    if db and db.hidden then
        mainframe:Hide()
    else
        mainframe:Show()
    end

    if not hasPet then
        happinessValue = 0
        UpdateVisual()
        return
    end

    local state = GetPetHappiness and GetPetHappiness() or nil
    if state == 1 or state == 2 or state == 3 then
        happinessValue = state
    else
        happinessValue = 0
    end

    UpdateVisual()
end

local function ToggleLock(locked)
    db.locked = locked
    SyncBackupDb()
    mainframe:EnableMouse(not locked)

    if locked then
        happinessBarText:SetTextColor(1, 1, 1)
        if petXpBarText then
            petXpBarText:SetTextColor(1, 1, 1)
        end
        if petInfoText then
            petInfoText:SetTextColor(1, 0.82, 0)
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
            petInfoText:SetTextColor(1, 0.82, 0)
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

    if not TurtlePetHappinessCharDB then
        TurtlePetHappinessCharDB = {}
    end

    if not TurtlePetHappinessDB then
        TurtlePetHappinessDB = {}
    end

    db = TurtlePetHappinessCharDB

    local characterKey = GetCharacterKey()
    if characterKey then
        if type(TurtlePetHappinessDB.characters) ~= "table" then
            TurtlePetHappinessDB.characters = {}
        end
        if type(TurtlePetHappinessDB.characters[characterKey]) ~= "table" then
            TurtlePetHappinessDB.characters[characterKey] = {}
        end
        backupDb = TurtlePetHappinessDB.characters[characterKey]
    end

    if next(db) == nil and backupDb and next(backupDb) ~= nil then
        for key, _ in pairs(DEFAULTS) do
            if backupDb[key] ~= nil then
                db[key] = backupDb[key]
            end
        end
    end

    if next(db) == nil and TurtlePetHappinessDB then
        for key, value in pairs(DEFAULTS) do
            if TurtlePetHappinessDB[key] ~= nil then
                db[key] = TurtlePetHappinessDB[key]
            end
        end
    end

    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end

    SyncBackupDb()

    mainframe:SetWidth(db.width)
    mainframe:SetHeight(db.height + 76)
    mainframe:SetFrameStrata("MEDIUM")

    happinessBarFrame = CreateFrame("Frame", nil, mainframe)
    happinessBarFrame:SetParent(mainframe)
    happinessBarFrame:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 6, -40)
    happinessBarFrame:SetWidth(db.width - 12)
    happinessBarFrame:SetHeight(db.height + 5)

    happinessBarFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })
    happinessBarFrame:SetBackdropColor(0, 0, 0, 0.5)
    happinessBarFrame:SetBackdropBorderColor(.7, .7, .7, 1)

    happinessBar = CreateFrame("StatusBar", nil, happinessBarFrame)
    happinessBar:SetParent(happinessBarFrame)
    happinessBar:SetPoint("TOPLEFT", happinessBarFrame, "TOPLEFT", 3, -4)
    happinessBar:SetPoint("TOPRIGHT", happinessBarFrame, "TOPRIGHT", -4, 0)
    happinessBar:SetHeight(13)
    happinessBar:SetMinMaxValues(0, 3)
    happinessBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    happinessBar.bg = happinessBar:CreateTexture(nil, "BACKGROUND")
    happinessBar.bg:SetAllPoints(happinessBar)
    happinessBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    happinessBar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

    happinessBarText = happinessBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    happinessBarText:SetParent(happinessBar)
    happinessBarText:SetPoint("CENTER", happinessBar, "CENTER", 0, 1)
    happinessBarText:SetJustifyH("CENTER")

    petXpBarFrame = CreateFrame("Frame", nil, mainframe)
    petXpBarFrame:SetParent(mainframe)
    petXpBarFrame:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 6, -62)
    petXpBarFrame:SetWidth(db.width - 12)
    petXpBarFrame:SetHeight(db.height + 5)
    petXpBarFrame:SetBackdropBorderColor(.7, .7, .7, 1)

    petXpBarFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
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
    petXpBarText:SetPoint("CENTER", petXpBar, "CENTER", 0, 1)
    petXpBarText:SetJustifyH("CENTER")
    petXpBarText:SetText("XP N/A")

    petInfoText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    petInfoText:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 8, -9)
    petInfoText:SetJustifyH("LEFT")
    petInfoText:SetText("No active pet")

    loyaltyInfoText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loyaltyInfoText:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 8, -25)
    loyaltyInfoText:SetJustifyH("CENTER")
    loyaltyInfoText:SetText("")

    petTrainingPointsLabelText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petTrainingPointsLabelText:SetPoint("TOPRIGHT", mainframe, "TOPRIGHT", -28, -26)
    petTrainingPointsLabelText:SetJustifyH("RIGHT")
    petTrainingPointsLabelText:SetText("")

    petTrainingPointsText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petTrainingPointsText:SetPoint("TOPRIGHT", mainframe, "TOPRIGHT", -8, -26)
    petTrainingPointsText:SetJustifyH("RIGHT")
    petTrainingPointsText:SetText("")

    petDietIconFrame = CreateFrame("Frame", nil, mainframe)
    petDietIconFrame:SetPoint("TOPRIGHT", mainframe, "TOPRIGHT", -27, -8)
    petDietIconFrame:SetWidth(16)
    petDietIconFrame:SetHeight(16)
    petDietIconFrame:SetFrameStrata("HIGH")
    petDietIconFrame:SetFrameLevel(mainframe:GetFrameLevel() + 10)
    petDietIconFrame:EnableMouse(true)

    petDietIconFrame:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end

        GameTooltip:SetOwner(petDietIconFrame, "ANCHOR_RIGHT")
        GameTooltip:SetText("Pet diet")
        GameTooltip:AddLine(GetPetDietTooltipText(), 1, 1, 1, true)
        GameTooltip:Show()
    end)

    petDietIconFrame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    petDietIconTexture = petDietIconFrame:CreateTexture(nil, "OVERLAY")
    petDietIconTexture:SetAllPoints(petDietIconFrame)
    petDietIconTexture:SetTexture("Interface\\Icons\\INV_Misc_Food_15")
    petDietIconFrame:Show()

    helpIconFrame = CreateFrame("Frame", nil, mainframe)
    helpIconFrame:SetPoint("TOPRIGHT", mainframe, "TOPRIGHT", -7, -8)
    helpIconFrame:SetWidth(16)
    helpIconFrame:SetHeight(16)
    helpIconFrame:SetFrameStrata("HIGH")
    helpIconFrame:SetFrameLevel(mainframe:GetFrameLevel() + 10)
    helpIconFrame:EnableMouse(true)

    helpIconFrame:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end

        GameTooltip:SetOwner(helpIconFrame, "ANCHOR_RIGHT")
        GameTooltip:SetText("Commands")
        GameTooltip:AddLine("/tph [lock, unlock, reset, hide, show]", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    helpIconFrame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    helpIconTexture = helpIconFrame:CreateTexture(nil, "OVERLAY")
    helpIconTexture:SetAllPoints(helpIconFrame)
    helpIconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    helpIconFrame:Show()

    mainframe:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })
    mainframe:SetBackdropColor(0, 0, 0, 0.5)
    mainframe:SetBackdropBorderColor(.7, .7, .7, 1)

    mainframe:RegisterForDrag("LeftButton")
    mainframe:SetMovable(true)
    mainframe:SetClampedToScreen(true)
    mainframe:SetScript("OnDragStart", function()
        if not db.locked then
            mainframe:StartMoving()
        end
    end)
    mainframe:SetScript("OnDragStop", function()
        mainframe:StopMovingOrSizing()
        SavePosition()
    end)

    ApplyPosition()
    if db.hidden then
        mainframe:Hide()
    else
        mainframe:Show()
    end
    happinessValue = Clamp(db.value or 0, 0, 3)
    ToggleLock(db.locked)

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
            db.point = DEFAULTS.point
            db.x = DEFAULTS.x
            db.y = DEFAULTS.y
            SyncBackupDb()
            ApplyPosition()
            print("Turtle Pet Happiness: position reset")
        elseif input == "hide" then
            db.hidden = true
            SyncBackupDb()
            mainframe:Hide()
            print("Turtle Pet Happiness: hidden")
        elseif input == "show" then
            db.hidden = false
            db.point = DEFAULTS.point
            db.x = DEFAULTS.x
            db.y = DEFAULTS.y
            SyncBackupDb()
            ApplyPosition()
            mainframe:Show()
            print("Turtle Pet Happiness: shown at center")
        else
            print("Turtle Pet Happiness commands: /tph lock, /tph unlock, /tph reset, /tph hide, /tph show")
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
    elseif evt == "UNIT_PET_EXPERIENCE" then
        if not a1 or a1 == "pet" then
            SyncToGameState(false)
        end
    elseif evt == "PLAYER_XP_UPDATE" then
        SyncToGameState(false)
    elseif evt == "CHAT_MSG_COMBAT_XP_GAIN" then
        SyncToGameState(false)
    elseif evt == "PET_BAR_UPDATE" or evt == "PET_UI_UPDATE" then
        SyncToGameState(false)
    end
end)

mainframe:RegisterEvent("ADDON_LOADED")
mainframe:RegisterEvent("PLAYER_LOGIN")
mainframe:RegisterEvent("PLAYER_ENTERING_WORLD")
mainframe:RegisterEvent("UNIT_HAPPINESS")
mainframe:RegisterEvent("UNIT_PET")
mainframe:RegisterEvent("UNIT_PET_EXPERIENCE")
mainframe:RegisterEvent("PLAYER_XP_UPDATE")
mainframe:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
mainframe:RegisterEvent("PET_BAR_UPDATE")
mainframe:RegisterEvent("PET_UI_UPDATE")

mainframe:SetScript("OnHide", function()
    if db then
        db.value = happinessValue
        SyncBackupDb()
    end
end)
