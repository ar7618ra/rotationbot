-- FrostmourneRotation.lua
-- Warlock Rotation for WotLK 3.3.5a (Affliction + Demonology Support)
print("|cff00ff00FrostmourneRotation (Dual Spec v2.0) Loaded.|r")

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
text:SetText("PQR Running")

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
    ["Healthstone"] = 0,
    ["Immolate"] = 0,
    ["Incinerate"] = 0,
    ["Soul Fire"] = 0
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
    if not start then return false end
    if enabled == 0 then return false end
    if start > 0 and duration > 1.5 then return false end
    
    -- Mana/Resource Check
    local usable, noMana = IsUsableSpell(spellName)
    if not usable or noMana then return false end
    
    return true
end

local function IsItemReady(slotID)
    local start, duration, enabled = GetInventoryItemCooldown("player", slotID)
    if not start then return false end
    if enabled == 0 then return false end
    if start > 0 and duration > 1.5 then return false end
    return true
end

local function IsItemReadyByID(itemID)
    if GetItemCount(itemID) == 0 then return false end
    local start, duration, enabled = GetItemCooldown(itemID)
    if not start then return false end
    if enabled == 0 then return false end
    if start > 0 and duration > 1.5 then return false end
    return true
end

local function DetermineSpec()
    local _, _, pointsAff = GetTalentTabInfo(1)
    local _, _, pointsDemo = GetTalentTabInfo(2)
    local _, _, pointsDestro = GetTalentTabInfo(3)
    
    pointsAff = pointsAff or 0
    pointsDemo = pointsDemo or 0
    pointsDestro = pointsDestro or 0
    
    if pointsDemo > pointsAff and pointsDemo > pointsDestro then
        return "DEMO"
    end
    return "AFFLICTION"
end

local debugStep = ""

local function SafeUpdate(self, elapsed)
    debugStep = "Start"
    self.TimeSinceLastUpdate = (self.TimeSinceLastUpdate or 0) + elapsed
    if self.TimeSinceLastUpdate < 0.02 then return end
    self.TimeSinceLastUpdate = 0

    debugStep = "Spec"
    local spec = DetermineSpec()
    debugStep = "Stats"
    local currentTime = GetTime()
    local myHealthPct = (UnitHealth("player") or 0) / (UnitHealthMax("player") or 1)
    local targetHealthPct = (UnitHealth("target") or 0) / (UnitHealthMax("target") or 1)
    local manaPct = (UnitPower("player") or 0) / (UnitPowerMax("player") or 1)
    local isMoving = (GetUnitSpeed("player") > 0)

    -- GLOBAL: Healthstone (Key Z)
    if myHealthPct < 0.4 and (currentTime - (lastCastTime["Healthstone"] or 0) > 2.0) then
        if IsItemReadyByID(36892) then
            lastCastTime["Healthstone"] = currentTime
            SetColor(0.5, 0, 0) -- Maroon
            return
        end
    end

    -- GLOBAL: Fel Armor (Key G - Brown)
    -- Priority: Maintenance. Check if missing.
    local hasFelArmor = HasBuff("player", "Fel Armor")
    -- Also check Demon Armor if Fel Armor is unknown? No, stick to Fel Armor for 3.3.5 endgame.
    if not hasFelArmor and (currentTime - (lastCastTime["Fel Armor"] or 0) > 2.0) then
        -- Only cast if we have mana
        if manaPct > 0.1 then
            lastCastTime["Fel Armor"] = currentTime
            SetColor(0.55, 0.27, 0.07) -- Brown
            return
        end
    end

    -- GLOBAL: Pet Management (Priority: High)
    -- Key 0 (Teal)
    -- 1. Summon if missing
    debugStep = "Pet"
    if not UnitExists("pet") and (currentTime - (lastCastTime["Pet"] or 0) > 5.0) then
        local shouldSummon = false
        if not UnitAffectingCombat("player") then shouldSummon = true
        elseif IsSpellReady("Fel Domination") then shouldSummon = true end
        
        if shouldSummon then
            lastCastTime["Pet"] = currentTime
            SetColor(0, 0.5, 0.5) -- Teal
            return
        end
    end
    -- 2. Demonic Empowerment (Buff)
    if UnitExists("pet") and UnitAffectingCombat("player") and IsSpellReady("Demonic Empowerment") then
        if (currentTime - (lastCastTime["Pet"] or 0) > 2.0) then
            lastCastTime["Pet"] = currentTime
            SetColor(0, 0.5, 0.5) -- Teal (Key 0)
            return
        end
    end

    debugStep = "TargetCheck"
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then
        SetColor(0.2, 0.2, 0.2) -- Dark Gray
        return
    end

    -- GLOBAL: Life Tap (Key 7)
    debugStep = "LifeTap"
    local hasLifeTapBuff, lifeTapExpire = HasBuff("player", "Life Tap")
    local timeRemaining = (lifeTapExpire or 0) - currentTime
    if (not hasLifeTapBuff or timeRemaining < 20) and myHealthPct > 0.3 then
        local cd = currentTime - (lastCastTime["Life Tap"] or 0)
        if (UnitAffectingCombat("player") or UnitExists("target")) and cd > 1.5 then
            lastCastTime["Life Tap"] = currentTime
            SetColor(0, 1, 1) -- Cyan
            return
        end
    end
    
    -- GLOBAL: Mana Restore (Key 7)
    local tapManaThreshold = 0.35
    local tapHpThreshold = 0.5
    if manaPct < 0.1 then tapHpThreshold = 0.25 end -- Desperate Tap if OOM

    -- Removed hardcoded 1.5s throttle. Use IsSpellReady to respect GCD (Haste).
    if manaPct < tapManaThreshold and myHealthPct > tapHpThreshold and IsSpellReady("Life Tap") then
        lastCastTime["Life Tap"] = currentTime
        SetColor(0, 1, 1) -- Cyan
        return
    end

    -- GLOBAL: Cooldowns (Key 8)
    debugStep = "Cooldowns"
    if UnitAffectingCombat("player") and (currentTime - (lastCastTime["Cooldowns"] or 0) > 2.0) then
        local useCD = false
        if IsSpellReady("Blood Fury") then useCD = true end
        if IsItemReady(13) then useCD = true end
        if IsItemReady(14) then useCD = true end
        
        if useCD then
            lastCastTime["Cooldowns"] = currentTime
            SetColor(1, 0.5, 0) -- Orange
            return
        end
    end

    -- GLOBAL: AOE (Seed) - Key 9
    if IsShiftKeyDown() and IsSpellReady("Seed of Corruption") and not isMoving then
        SetColor(1, 0.41, 0.7) -- Pink
        return
    end

    -- SPECIFFIC LOGIC
    debugStep = "Logic-" .. spec
    if spec == "DEMO" then
        -- DEMONOLOGY ROTATION
        
        -- 1. Metamorphosis (Key 8 - Orange)
        -- Demo uses Meta on CD for damage
        if IsSpellReady("Metamorphosis") and UnitAffectingCombat("player") and (currentTime - (lastCastTime["Cooldowns"] or 0) > 2.0) then
            lastCastTime["Cooldowns"] = currentTime
            SetColor(1, 0.5, 0) -- Orange
            return
        end

        -- 2. Decimation -> Soul Fire (Key 6 - White)
        -- Proc: "Decimation" or Execute Range
        local hasDecimation = HasBuff("player", "Decimation")
        if (hasDecimation or targetHealthPct < 0.35) and not isMoving then
             -- Anti-Clip check not needed for Soul Fire (Cast time)
             if IsSpellReady("Soul Fire") then
                 lastCastTime["Soul Fire"] = currentTime
                 SetColor(1, 1, 1) -- White
                 return
             end
        end

        -- 3. Immolate (Key 1 - Red)
        local hasImmolate, immolateExpire = HasDebuff("target", "Immolate", "player")
        if (not hasImmolate or immolateExpire - currentTime < 3.0) and not isMoving then
            if IsSpellReady("Immolate") and (currentTime - (lastCastTime["Immolate"] or 0) > 2.0) then
                lastCastTime["Immolate"] = currentTime
                SetColor(1, 0, 0) -- Red
                return
            end
        end

        -- 4. Corruption (Key 3 - Blue)
        local hasCorruption = HasDebuff("target", "Corruption", "player")
        if not hasCorruption then
            lastCastTime["Corruption"] = currentTime
            SetColor(0, 0, 1) -- Blue
            return
        end

        -- 5. Curse of Doom/Agony (Key 4 - Yellow)
        local hasDoom = HasDebuff("target", "Curse of Doom", "player")
        local hasAgony, agonyExpire = HasDebuff("target", "Curse of Agony", "player")
        local hasElements = HasDebuff("target", "Curse of the Elements", "player")
        
        if not hasDoom and not hasAgony and not hasElements then
             -- Use Agony as default safer option
             lastCastTime["Curse of Agony"] = currentTime
             SetColor(1, 1, 0) -- Yellow
             return
        end
        if hasAgony and (agonyExpire - currentTime < 5.0) then
             lastCastTime["Curse of Agony"] = currentTime
             SetColor(1, 1, 0) -- Yellow
             return
        end

        -- 6. Molten Core -> Incinerate (Key 5 - Purple)
        local hasMoltenCore = HasBuff("player", "Molten Core")
        if hasMoltenCore and not isMoving then
             if IsSpellReady("Incinerate") then
                 lastCastTime["Incinerate"] = currentTime
                 SetColor(1, 0, 1) -- Purple
                 return
             end
        end

        -- 7. Filler: Shadow Bolt (Key 2 - Green)
        if not isMoving then
             if IsSpellReady("Shadow Bolt") then
                 lastCastTime["Shadow Bolt"] = currentTime
                 SetColor(0, 1, 0) -- Green
                 return
             end
        end

    else
        -- AFFLICTION ROTATION
        
        -- Opener Reset
        debugStep = "OpenerCheck"
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

        -- Opener Sequence
        debugStep = "OpenerRun"
        if openerStep > 0 then
            local spellCast = UnitCastingInfo("player")
            
            -- 1: SB
            if openerStep == 1 then
                if isMoving then return end
                if (currentTime - lastCastTime["Shadow Bolt"] < 5) and (currentTime - lastCastTime["Shadow Bolt"] > 0.5) then openerStep = 2 return end
                if spellCast == "Shadow Bolt" then return end
                if IsSpellReady("Shadow Bolt") then lastCastTime["Shadow Bolt"] = currentTime SetColor(1, 0, 1) return end
            end
            -- 2: UA
            if openerStep == 2 then
                if isMoving then return end
                if (currentTime - lastCastTime["Unstable Affliction"] < 5) and (currentTime - lastCastTime["Unstable Affliction"] > 0.5) then openerStep = 3 return end
                if spellCast == "Unstable Affliction" then return end
                if IsSpellReady("Unstable Affliction") then lastCastTime["Unstable Affliction"] = currentTime SetColor(0, 1, 0) return end
            end
            -- 3: Haunt
            if openerStep == 3 then
                if isMoving then return end
                if (currentTime - lastCastTime["Haunt"] < 5) and (currentTime - lastCastTime["Haunt"] > 0.5) then openerStep = 4 return end
                if spellCast == "Haunt" then return end
                if IsSpellReady("Haunt") then lastCastTime["Haunt"] = currentTime SetColor(1, 0, 0) return end
            end
            -- 4: Agony
            if openerStep == 4 then
                if (currentTime - lastCastTime["Curse of Agony"] < 5) and (currentTime - lastCastTime["Curse of Agony"] > 0.5) then openerStep = 5 return end
                if IsSpellReady("Curse of Agony") then 
                    if (currentTime - lastCastTime["Curse of Agony"] > 2.0) then lastCastTime["Curse of Agony"] = currentTime end
                    SetColor(1, 1, 0) return 
                end
            end
            -- 5: Corruption
            if openerStep == 5 then
                if (currentTime - lastCastTime["Corruption"] < 5) and (currentTime - lastCastTime["Corruption"] > 0.5) then openerStep = 0 return end
                if IsSpellReady("Corruption") then 
                    if (currentTime - lastCastTime["Corruption"] > 2.0) then lastCastTime["Corruption"] = currentTime end
                    SetColor(0, 0, 1) return 
                end
            end
            return
        end

        -- Affliction Execute
        debugStep = "ExecuteCheck"
        local classification = UnitClassification("target")
        -- Significant if: Boss, Elite, Rare, OR High HP (> 200k for Dummies)
        local isSignificant = (classification == "worldboss" or classification == "rareelite" or classification == "elite" or UnitLevel("target") == -1 or UnitHealthMax("target") > 200000)
        
        if targetHealthPct < 0.25 and not isSignificant then
            -- Trash Logic: Just finish it off. No DOTs.
            if isMoving then return end 
            local channelName = UnitChannelInfo("player")
            if channelName == "Drain Soul" then return end
            if (currentTime - (lastCastTime["Drain Soul"] or 0) > 2.0) then
                lastCastTime["Drain Soul"] = currentTime
                SetColor(1, 1, 1) -- White
                return
            end
            return
        end

        -- Debuffs
        debugStep = "Debuffs"
        -- Real State (Server)
        local realHasHaunt, hauntExpire = HasDebuff("target", "Haunt", "player")
        local realHasUA, uaExpire = HasDebuff("target", "Unstable Affliction", "player")
        local realHasCorruption, corrExpire = HasDebuff("target", "Corruption", "player")
        local realHasAgony, agonyExpire = HasDebuff("target", "Curse of Agony", "player")
        local hasElements, _ = HasDebuff("target", "Curse of the Elements", "player")
        local hasDoom, _ = HasDebuff("target", "Curse of Doom", "player")
        
        local spellName = UnitCastingInfo("player")
        local isCastingHaunt = (spellName == "Haunt")
        local isCastingUA = (spellName == "Unstable Affliction")
        local isCasting = (spellName ~= nil)

        -- Safe State (Optimistic) - DISABLED to prevent False Positives
        -- We rely on real server data for PreCheck to ensure we don't spam SB if a DOT failed to apply.
        local safeHasHaunt = realHasHaunt
        local safeHasUA = realHasUA
        local safeHasCorruption = realHasCorruption
        local safeHasAgony = realHasAgony

        -- UA (MISSING) - Priority #1 (Emergency)
        -- If UA falls off, getting it back is more important than Haunt.
        debugStep = "UA_Missing"
        if not realHasUA then
            -- Do NOT throttle if missing. Spam it.
            if not isMoving and IsSpellReady("Unstable Affliction") and not isCastingUA then
                lastCastTime["Unstable Affliction"] = currentTime
                SetColor(0, 1, 0)
                return
            end
        end

        -- Haunt (Red)
        -- No throttle needed (CD based)
        debugStep = "Haunt"
        if not isMoving and IsSpellReady("Haunt") and not isCastingHaunt then
            lastCastTime["Haunt"] = currentTime
            SetColor(1, 0, 0)
            return
        end
        
        -- UA (REFRESH) - Priority #3
        debugStep = "UA_Refresh"
        -- Optimized Refresh: 2.5s remaining (Allows finishing a cast + casting UA)
        if uaExpire - currentTime < 2.5 then
            local throttle = (currentTime - (lastCastTime["Unstable Affliction"] or 0) < 2.0) and not isCasting
            if not isMoving and IsSpellReady("Unstable Affliction") and not isCastingUA and not throttle then
                lastCastTime["Unstable Affliction"] = currentTime
                SetColor(0, 1, 0)
                return
            end
        end
        -- Corruption (Blue)
        debugStep = "Corruption"
        if not realHasCorruption then
            -- If missing, do NOT throttle.
            if IsSpellReady("Corruption") then
                lastCastTime["Corruption"] = currentTime
                SetColor(0, 0, 1)
                return
            end
        end
        -- Agony (Yellow)
        debugStep = "Agony"
        if (not realHasAgony and not hasElements and not hasDoom) or (realHasAgony and agonyExpire - currentTime < 5.0) then
            local throttle = realHasAgony and (currentTime - (lastCastTime["Curse of Agony"] or 0) < 2.0) and not isCasting
            if IsSpellReady("Curse of Agony") and not throttle then
                lastCastTime["Curse of Agony"] = currentTime
                SetColor(1, 1, 0)
                return
            end
        end
        -- Execute Filler (Drain Soul - White)
        debugStep = "ExecFiller"
        if targetHealthPct < 0.25 then
            if isMoving then return end
            local channelName = UnitChannelInfo("player")
            if channelName == "Drain Soul" then return end
            if (currentTime - (lastCastTime["Drain Soul"] or 0) > 2.0) then
                lastCastTime["Drain Soul"] = currentTime
                SetColor(1, 1, 1)
                return
            end
            return
        end
        -- Normal Filler (Shadow Bolt - Purple)
        debugStep = "NormalFiller"
        if not isMoving then
            -- Pre-Check uses SAFE state (Optimistic) to prevent pauses
            debugStep = "PreCheck"
            -- Synced PreCheck with Refresh Thresholds to avoid Dead Zone
            if (not safeHasUA or uaExpire - currentTime < 2.5) or
               (not safeHasHaunt or hauntExpire - currentTime < 2.0) or
               ((not safeHasAgony and not hasElements and not hasDoom) or (safeHasAgony and agonyExpire - currentTime < 2.0)) then
                SetColor(0.2, 0.2, 0.2)
                return
            end
            lastCastTime["Shadow Bolt"] = currentTime
            SetColor(1, 0, 1)
        end
    end
end

local function OnUpdate(self, elapsed)
    local status, err = pcall(SafeUpdate, self, elapsed)
    if not status then
        text:SetText("ERR: " .. debugStep .. " " .. tostring(err))
        SetColor(0, 0, 0) -- Black on error
    end
end

frame:SetScript("OnUpdate", OnUpdate)
frame:Show()

SLASH_FROST1 = "/frost"
SlashCmdList["FROST"] = function(msg)
    print("FrostmourneRotation Status:")
    local _, _, pointsAff = GetTalentTabInfo(1)
    local _, _, pointsDemo = GetTalentTabInfo(2)
    local spec = "AFFLICTION"
    if (pointsDemo or 0) > (pointsAff or 0) then spec = "DEMO" end
    print("- Spec: " .. spec)
    
    if UnitExists("target") then
        print("- Target: " .. (UnitName("target") or "Unknown"))
        local hp = (UnitHealth("target") or 0) / (UnitHealthMax("target") or 1)
        print("- Health Pct: " .. hp)
        local hasLT, expire = HasBuff("player", "Life Tap")
        local ltRem = (expire or 0) - GetTime()
        print("- Life Tap Buff: " .. tostring(hasLT) .. " (" .. math.floor(ltRem) .. "s)")
    else
        print("- No Target")
    end
end
