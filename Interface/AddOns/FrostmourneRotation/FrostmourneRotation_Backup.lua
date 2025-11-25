-- FrostmourneRotation.lua
-- Warlock Affliction Rotation for WotLK 3.3.5a
print("|cff00ff00FrostmourneRotation (Affliction v1.7 Clean) Loaded.|r")

local frame = CreateFrame("Frame", "FrostmourneRotationFrame", UIParent)
frame:SetWidth(32) 
frame:SetHeight(32)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
frame:SetFrameStrata("TOOLTIP")

local texture = frame:CreateTexture(nil, "BACKGROUND")
texture:SetAllPoints(frame)
texture:SetTexture(0.2, 0.2, 0.2) -- Dark Gray (Idle/Alive)

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("LEFT", frame, "RIGHT", 5, 0)
text:SetText("PQR Running (Affliction)")

local lastCastTime = {
    ["Haunt"] = 0,
    ["Unstable Affliction"] = 0,
    ["Life Tap"] = 0,
    ["Shadow Bolt"] = 0,
    ["Curse of Agony"] = 0,
    ["Corruption"] = 0,
    ["Cooldowns"] = 0,
    ["Drain Soul"] = 0,
    ["Pet"] = 0,
    ["Healthstone"] = 0
}

local openerStep = 0
local lastTargetGUID = nil

local function SetColor(r, g, b)
    texture:SetTexture(r, g, b)
end

local function HasDebuff(target, spellName, source)
    for i=1,40 do
        local name, _, _, _, _, _, expirationTime, unitCaster = UnitDebuff(target, i)
        if not name then break end
        if name == spellName and (not source or unitCaster == source) then
            return true, expirationTime or 0
        end
    end
    return false, 0
end

local function HasBuff(target, spellName)
    for i=1,40 do
        local name, _, _, _, _, _, expirationTime = UnitBuff(target, i)
        if not name then break end
        if name == spellName then
            return true, expirationTime or 0
        end
    end
    return false, 0
end

local function IsSpellReady(spellName)
    local start, duration, enabled = GetSpellCooldown(spellName)
    if enabled == 0 then return false end
    if start > 0 and duration > 1.5 then return false end
    return true
end

local function IsItemReady(slotID)
    local start, duration, enabled = GetInventoryItemCooldown("player", slotID)
    if enabled == 0 then return false end
    if start > 0 and duration > 1.5 then return false end
    return true
end

local function IsItemReadyByID(itemID)
    if GetItemCount(itemID) == 0 then return false end
    local start, duration, enabled = GetItemCooldown(itemID)
    if enabled == 0 then return false end
    if start > 0 and duration > 1.5 then return false end
    return true
end

local function SafeUpdate(self, elapsed)
    self.TimeSinceLastUpdate = (self.TimeSinceLastUpdate or 0) + elapsed
    if self.TimeSinceLastUpdate < 0.1 then return end
    self.TimeSinceLastUpdate = 0

    -- Healthstone / Defensive (Priority: Critical)
    -- Key Z (Maroon)
    local myHealthPct = (UnitHealth("player") or 0) / (UnitHealthMax("player") or 1)
    local currentTime = GetTime()
    
    if myHealthPct < 0.4 and (currentTime - (lastCastTime["Healthstone"] or 0) > 2.0) then
        if IsItemReadyByID(36892) then
            lastCastTime["Healthstone"] = currentTime
            SetColor(0.5, 0, 0) -- Maroon (Key Z)
            return
        end
    end
    
    -- Pet Management (Priority: High)
    -- Key 0 (Teal)
    if not UnitExists("pet") and (currentTime - (lastCastTime["Pet"] or 0) > 5.0) then
        local shouldSummon = false
        if not UnitAffectingCombat("player") then
             shouldSummon = true
        elseif IsSpellReady("Fel Domination") then
             shouldSummon = true
        end
        
        if shouldSummon then
            lastCastTime["Pet"] = currentTime
            SetColor(0, 0.5, 0.5) -- Teal (Key 0)
            return
        end
    end

    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then
        SetColor(0.2, 0.2, 0.2) -- Dark Gray (Idle)
        return
    end

    local targetHealthPct = (UnitHealth("target") or 0) / (UnitHealthMax("target") or 1)
    local manaPct = (UnitPower("player") or 0) / (UnitPowerMax("player") or 1)
    local isMoving = (GetUnitSpeed("player") > 0)

    -- Target Change Detection & Opener Reset
    local guid = UnitGUID("target")
    if guid ~= lastTargetGUID then
        lastTargetGUID = guid
        local hasUA, _ = HasDebuff("target", "Unstable Affliction", "player")
        if targetHealthPct > 0.25 and not hasUA then
            openerStep = 1
        else
            openerStep = 0
        end
    end

    -- AOE MODE (Hold Shift)
    -- Cast Seed of Corruption (Key 9)
    if IsShiftKeyDown() then
        if IsSpellReady("Seed of Corruption") and not isMoving then
             if not isMoving then
                SetColor(1, 0.41, 0.7) -- Hot Pink (Key 9) approx
                return
             end
        end
    end

    -- 0. Life Tap Logic
    local hasLifeTapBuff, lifeTapExpire = HasBuff("player", "Life Tap")
    local timeRemaining = (lifeTapExpire or 0) - currentTime
    
    if (not hasLifeTapBuff or timeRemaining < 20) and myHealthPct > 0.3 then
        local cd = currentTime - (lastCastTime["Life Tap"] or 0)
        if (UnitAffectingCombat("player") or UnitExists("target")) and cd > 1.5 then
            lastCastTime["Life Tap"] = currentTime
            SetColor(0, 1, 1) -- Cyan (Key 7)
            return
        end
    end

    -- COOLDOWNS (Priority: High)
    if UnitAffectingCombat("player") and (currentTime - (lastCastTime["Cooldowns"] or 0) > 2.0) then
        local useCD = false
        if IsSpellReady("Blood Fury") then useCD = true end
        if IsItemReady(13) then useCD = true end
        if IsItemReady(14) then useCD = true end
        
        if useCD then
            lastCastTime["Cooldowns"] = currentTime
            SetColor(1, 0.5, 0) -- Orange (Key 8)
            return
        end
    end

    -- Mana Restore
    if manaPct < 0.2 and myHealthPct > 0.5 and (currentTime - (lastCastTime["Life Tap"] or 0) > 1.5) then
        lastCastTime["Life Tap"] = currentTime
        SetColor(0, 1, 1) -- Cyan (Key 7)
        return
    end

    -- OPENER SEQUENCE
    if openerStep > 0 then
        local spellCast = UnitCastingInfo("player")
        
        -- Step 1: Shadow Bolt
        if openerStep == 1 then
            if isMoving then return end
            if (currentTime - lastCastTime["Shadow Bolt"] < 5) and (currentTime - lastCastTime["Shadow Bolt"] > 0.5) then
                openerStep = 2
                return
            end
            if spellCast == "Shadow Bolt" then return end
            
            if IsSpellReady("Shadow Bolt") then
                lastCastTime["Shadow Bolt"] = currentTime
                SetColor(1, 0, 1) -- Purple (Key 5)
                return
            end
        end

        -- Step 2: Unstable Affliction
        if openerStep == 2 then
            if isMoving then return end
            if (currentTime - lastCastTime["Unstable Affliction"] < 5) and (currentTime - lastCastTime["Unstable Affliction"] > 0.5) then
                openerStep = 3
                return
            end
            if spellCast == "Unstable Affliction" then return end
            
            if IsSpellReady("Unstable Affliction") then
                lastCastTime["Unstable Affliction"] = currentTime
                SetColor(0, 1, 0) -- Green (Key 2)
                return
            end
        end

        -- Step 3: Haunt
        if openerStep == 3 then
            if isMoving then return end
            if (currentTime - lastCastTime["Haunt"] < 5) and (currentTime - lastCastTime["Haunt"] > 0.5) then
                openerStep = 4
                return
            end
            if spellCast == "Haunt" then return end
            
            if IsSpellReady("Haunt") then
                lastCastTime["Haunt"] = currentTime
                SetColor(1, 0, 0) -- Red (Key 1)
                return
            end
        end

        -- Step 4: Curse of Agony
        if openerStep == 4 then
            if (currentTime - lastCastTime["Curse of Agony"] < 5) and (currentTime - lastCastTime["Curse of Agony"] > 0.5) then
                openerStep = 5
                return
            end
            
            if IsSpellReady("Curse of Agony") then
                if (currentTime - lastCastTime["Curse of Agony"] > 2.0) then
                    lastCastTime["Curse of Agony"] = currentTime
                end
                SetColor(1, 1, 0) -- Yellow (Key 4)
                return
            end
        end

        -- Step 5: Corruption
        if openerStep == 5 then
            if (currentTime - lastCastTime["Corruption"] < 5) and (currentTime - lastCastTime["Corruption"] > 0.5) then
                openerStep = 0
                return
            end
            
            if IsSpellReady("Corruption") then
                if (currentTime - lastCastTime["Corruption"] > 2.0) then
                    lastCastTime["Corruption"] = currentTime
                end
                SetColor(0, 0, 1) -- Blue (Key 3)
                return
            end
        end
        
        return
    end

    -- 1. Execute Phase Logic (Smart)
    local classification = UnitClassification("target")
    local isSignificant = (classification == "worldboss" or classification == "rareelite" or classification == "elite" or UnitLevel("target") == -1)
    
    if targetHealthPct < 0.25 and not isSignificant then
        if isMoving then return end 
        local channelName = UnitChannelInfo("player")
        if channelName == "Drain Soul" then return end
        
        if (currentTime - (lastCastTime["Drain Soul"] or 0) > 2.0) then
            lastCastTime["Drain Soul"] = currentTime
            SetColor(1, 1, 1) -- White (Key 6)
            return
        end
        return
    end

    -- Gather Debuffs
    local hasHaunt, hauntExpire = HasDebuff("target", "Haunt", "player")
    local hasUA, uaExpire = HasDebuff("target", "Unstable Affliction", "player")
    local hasCorruption, corrExpire = HasDebuff("target", "Corruption", "player")
    local hasAgony, agonyExpire = HasDebuff("target", "Curse of Agony", "player")
    local hasElements, _ = HasDebuff("target", "Curse of the Elements", "player")
    local hasDoom, _ = HasDebuff("target", "Curse of Doom", "player")

    -- Casting Check
    local spellName = UnitCastingInfo("player")
    local isCastingHaunt = (spellName == "Haunt")
    local isCastingUA = (spellName == "Unstable Affliction")

    -- 2. Haunt
    if not isMoving and IsSpellReady("Haunt") and not isCastingHaunt and (currentTime - (lastCastTime["Haunt"] or 0) > 2.0) then
        lastCastTime["Haunt"] = currentTime
        SetColor(1, 0, 0) -- Red (Key 1)
        return
    end

    -- 3. Unstable Affliction
    if not hasUA or (uaExpire - currentTime < 5.0) then
        if not isMoving and IsSpellReady("Unstable Affliction") and not isCastingUA and (currentTime - (lastCastTime["Unstable Affliction"] or 0) > 2.0) then
            lastCastTime["Unstable Affliction"] = currentTime
            SetColor(0, 1, 0) -- Green (Key 2)
            return
        end
    end

    -- 4. Corruption
    if not hasCorruption then
        lastCastTime["Corruption"] = currentTime
        SetColor(0, 0, 1) -- Blue (Key 3)
        return
    end

    -- 5. Curse of Agony
    if not hasAgony and not hasElements and not hasDoom then
        lastCastTime["Curse of Agony"] = currentTime
        SetColor(1, 1, 0) -- Yellow (Key 4)
        return
    end
    if hasAgony and (agonyExpire - currentTime < 5.0) then
        lastCastTime["Curse of Agony"] = currentTime
        SetColor(1, 1, 0) -- Yellow (Key 4)
        return
    end

    -- 6. Filler (Shadow Bolt OR Drain Soul)
    if isMoving then return end

    -- EXECUTE FILLER (Boss/Elite < 25%)
    if targetHealthPct < 0.25 then
        local channelName = UnitChannelInfo("player")
        if channelName == "Drain Soul" then return end
        
        if (currentTime - (lastCastTime["Drain Soul"] or 0) > 2.0) then
            lastCastTime["Drain Soul"] = currentTime
            SetColor(1, 1, 1) -- White (Key 6)
            return
        end
        return
    end

    -- NORMAL FILLER (Shadow Bolt)
    if (not hasUA or uaExpire - currentTime < 5.0) or
       (not hasHaunt or hauntExpire - currentTime < 5.0) or
       (not hasAgony and (not hasElements and not hasDoom)) or
       (hasAgony and agonyExpire - currentTime < 5.0) then
        -- Just wait. Do not cast filler.
        SetColor(0.2, 0.2, 0.2)
        return
    end
    lastCastTime["Shadow Bolt"] = currentTime
    SetColor(1, 0, 1) -- Purple (Key 5)
end

local function OnUpdate(self, elapsed)
    local status, err = pcall(SafeUpdate, self, elapsed)
    if not status then
        text:SetText("ERROR: " .. tostring(err))
        SetColor(0, 0, 0) -- Black on error
    end
end

frame:SetScript("OnUpdate", OnUpdate)
frame:Show()

SLASH_FROST1 = "/frost"
SlashCmdList["FROST"] = function(msg)
    print("FrostmourneRotation Status:")
    if UnitExists("target") then
        print("- Target: " .. (UnitName("target") or "Unknown"))
        local hp = (UnitHealth("target") or 0) / (UnitHealthMax("target") or 1)
        print("- Health Pct: " .. hp)
        local isMoving = (GetUnitSpeed("player") > 0)
        print("- Moving: " .. tostring(isMoving))
    else
        print("- No Target")
    end
end
