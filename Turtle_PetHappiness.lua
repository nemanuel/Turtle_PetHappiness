local ADDON_NAME = "Turtle_PetHappiness"

local DEFAULTS = {
    point = "CENTER",
    x = 0,
    y = -180,
    width = 220,
    height = 16,
    locked = false,
    hidden = false,
    value = 100,
}

local mainframe = CreateFrame("Frame", "TurtlePetHappinessFrame", UIParent)
local happinessBarFrame
local happinessBar
local happinessBarText
local petXpBarFrame
local petXpBar
local petXpBarText
local petInfoText
local loyaltyInfoText
local petDietIconFrame
local petDietIconTexture

local happinessValue = 0
local hasPet = false
local initialized = false
local db

local function Clamp(value, minVal, maxVal)
    if value < minVal then
        return minVal
    elseif value > maxVal then
        return maxVal
    end
    return value
end

local function SavePosition()
    local point, _, _, x, y = mainframe:GetPoint(1)
    db.point = point
    db.x = x
    db.y = y
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

local PET_FAMILY_DIET_FALLBACK = {
    ["Bat"] = "Fruit, Fungus",
    ["Bear"] = "Bread, Cheese, Fish, Fruit, Fungus, Meat",
    ["Boar"] = "Bread, Fruit, Fungus",
    ["Carrion Bird"] = "Meat",
    ["Cat"] = "Fish, Meat",
    ["Core Hound"] = "Meat",
    ["Crab"] = "Fish",
    ["Crocolisk"] = "Fish, Meat",
    ["Gorilla"] = "Fruit, Fungus",
    ["Hyena"] = "Meat",
    ["Owl"] = "Meat",
    ["Raptor"] = "Meat",
    ["Scorpid"] = "Meat",
    ["Spider"] = "Meat",
    ["Tallstrider"] = "Fruit, Fungus",
    ["Turtle"] = "Fish, Fruit",
    ["Wind Serpent"] = "Bread, Cheese, Fish",
    ["Wolf"] = "Meat",
}

local function GetPetDietTooltipText()
    if not UnitExists("pet") then
        return "No active pet"
    end

    if not GetPetFoodTypes then
        local family = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        return (family and PET_FAMILY_DIET_FALLBACK[family]) or "Unknown"
    end

    local result = { GetPetFoodTypes() }
    local foodTypes = nil

    if table.getn(result) == 1 and type(result[1]) == "table" then
        foodTypes = result[1]
    else
        foodTypes = result
    end

    if type(foodTypes) ~= "table" or table.getn(foodTypes) == 0 then
        local family = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        return (family and PET_FAMILY_DIET_FALLBACK[family]) or "Unknown"
    end

    local foods = ""
    for i = 1, table.getn(foodTypes) do
        local food = foodTypes[i]
        if type(food) == "string" and food ~= "" then
            if foods == "" then
                foods = food
            else
                foods = foods .. ", " .. food
            end
        end
    end

    if foods == "" then
        local family = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        return (family and PET_FAMILY_DIET_FALLBACK[family]) or "Unknown"
    end

    return foods
end

local function UpdateVisual()
    if not happinessBar or not happinessBarText or not petXpBar or not petXpBarText or not petInfoText or not loyaltyInfoText then
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

    if state == 1 or state == 2 or state == 3 then
        happinessBarText:SetText(string.format("Happiness %s", stateText))
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

    if not TurtlePetHappinessCharDB then
        TurtlePetHappinessCharDB = {}
    end

    db = TurtlePetHappinessCharDB

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

    mainframe:SetWidth(db.width)
    mainframe:SetHeight(db.height + 66)
    mainframe:SetFrameStrata("MEDIUM")

    happinessBarFrame = CreateFrame("Frame", nil, mainframe)
    happinessBarFrame:SetParent(mainframe)
    happinessBarFrame:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 4, -33)
    happinessBarFrame:SetWidth(db.width - 8)
    happinessBarFrame:SetHeight(db.height + 5)

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
    happinessBar:SetPoint("TOPLEFT", happinessBarFrame, "TOPLEFT", 4, -4)
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
    petXpBarFrame:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 4, -56)
    petXpBarFrame:SetWidth(db.width - 8)
    petXpBarFrame:SetHeight(db.height + 5)

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
    petXpBar:SetPoint("TOPLEFT", petXpBarFrame, "TOPLEFT", 4, -4)
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

    petInfoText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petInfoText:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 6, -6)
    petInfoText:SetJustifyH("LEFT")
    petInfoText:SetText("No active pet")

    loyaltyInfoText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loyaltyInfoText:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 5, -19)
    loyaltyInfoText:SetJustifyH("CENTER")
    loyaltyInfoText:SetText("")

    petDietIconFrame = CreateFrame("Frame", nil, mainframe)
    petDietIconFrame:SetPoint("TOPRIGHT", mainframe, "TOPRIGHT", -6, -7)
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
            ApplyPosition()
            print("Turtle Pet Happiness: position reset")
        elseif input == "hide" then
            db.hidden = true
            mainframe:Hide()
            print("Turtle Pet Happiness: hidden")
        elseif input == "show" then
            db.hidden = false
            db.point = DEFAULTS.point
            db.x = DEFAULTS.x
            db.y = DEFAULTS.y
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
    elseif evt == "PET_BAR_UPDATE" or evt == "PET_UI_UPDATE" then
        SyncToGameState(false)
    end
end)

mainframe:RegisterEvent("ADDON_LOADED")
mainframe:RegisterEvent("PLAYER_LOGIN")
mainframe:RegisterEvent("PLAYER_ENTERING_WORLD")
mainframe:RegisterEvent("UNIT_HAPPINESS")
mainframe:RegisterEvent("UNIT_PET")
mainframe:RegisterEvent("PET_BAR_UPDATE")
mainframe:RegisterEvent("PET_UI_UPDATE")

mainframe:SetScript("OnHide", function()
    if db then
        db.value = happinessValue
    end
end)
