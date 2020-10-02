
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local AFK = AFK
local DND = DND
local PVP = PVP
local LEVEL = LEVEL
local OFFLINE = FRIENDS_LIST_OFFLINE
local FACTION_HORDE = FACTION_HORDE
local FACTION_ALLIANCE = FACTION_ALLIANCE

local addon = TinyTooltip


--------------------------------------------------------------------------------------------------------
--                                                AURAS                                               --
--------------------------------------------------------------------------------------------------------

local auras = addon.auras

local function CreateAuraFrame(parent)
    local aura = CreateFrame("Frame",nil,parent);

    -- icon image
    aura.icon = aura:CreateTexture(nil,"BACKGROUND");
    aura.icon:SetAllPoints();
    aura.icon:SetTexCoord(0.07,0.93,0.07,0.93);

    -- stack count
    aura.count = aura:CreateFontString(nil,"OVERLAY");
    aura.count:SetPoint("BOTTOMRIGHT",1,0);

    -- cooldown overlay
    aura.cooldown = CreateFrame("Cooldown",nil, aura,"CooldownFrameTemplate");
    aura.cooldown:SetReverse(1);
    aura.cooldown:SetAllPoints();
    aura.cooldown:SetFrameLevel(aura:GetFrameLevel());

    -- border
    aura.border = aura:CreateTexture(nil,"OVERLAY");
    aura.border:SetPoint("TOPLEFT",-1,1);
    aura.border:SetPoint("BOTTOMRIGHT",1,-1);
    aura.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays");
    aura.border:SetTexCoord(0.296875,0.5703125,0,0.515625);

    -- add to available aura frames
    auras[#auras + 1] = aura;
    return aura;
end

-- querires auras of the specific auraType, and sets up the aura frame and anchors it in the desired place
local function DisplayAuras(tip, unit, auraType, startingAuraFrameIndex)

    local xOffsetBasis = (auraType == "HELPFUL" and 1 or -1);				-- is +1 or -1 based on horz anchoring

    local queryIndex = 1;							-- aura query index for this auraType
    local auraFrameIndex = startingAuraFrameIndex;	-- array index for the next aura frame, initialized to the starting index

    local horzAnchor1 = (auraType == "HELPFUL" and "LEFT" or "RIGHT");
    local horzAnchor2 = addon.anchorMirrors.vertical[horzAnchor1];

    local vertAnchor = addon.anchorMirrors.vertical[string.upper(addon.db.auras.position)]
    local anchor1 = vertAnchor..horzAnchor1;
    local anchor2 = addon.anchorMirrors.vertical[vertAnchor]..horzAnchor1;

    -- auras we can fit into one row based on the current size of the tooltip
    local aurasPerRow
    if vertAnchor == "TOP" then
        aurasPerRow = floor((tip:GetWidth() - 4) / (addon.db.auras.size + 1));
    else
        aurasPerRow = floor((tip:GetWidth() - 4) / (addon.db.auras.size + 1) * 0.85);
    end

    -- query auras
    while (true) do
        local _, iconTexture, count, debuffType, duration, endTime, casterUnit = UnitAura(unit,queryIndex,auraType);	-- [18.07.19] 8.0/BfA: "dropped second parameter"
        if (not iconTexture) or (auraFrameIndex / aurasPerRow > addon.db.auras.maxRows) then
            break;
        end
        if (not addon.db.auras.selfOnly or casterUnit == "player" or casterUnit == "pet") then
            local aura = auras[auraFrameIndex] or CreateAuraFrame(tip);

            -- Anchor It
            aura:ClearAllPoints();
            if ((auraFrameIndex - 1) % aurasPerRow == 0) or (auraFrameIndex == startingAuraFrameIndex) then
                -- new aura line
                local x = (xOffsetBasis * 2);
                local y = (addon.db.auras.size + 1) * floor((auraFrameIndex - 1) / aurasPerRow) + 8;

                y = (vertAnchor == "TOP" and -y or y);
                aura:SetPoint(anchor1,tip,anchor2,x,y);
            else
                -- anchor to last
                aura:SetPoint(horzAnchor1,auras[auraFrameIndex - 1],horzAnchor2,xOffsetBasis,0);
            end

            -- Cooldown
            if (addon.db.auras.showCooldown) and (duration and duration > 0 and endTime and endTime > 0) then
                aura.cooldown.noCooldownCount = not addon.db.auras.showCooldownTimer or nil;
                aura.cooldown:SetCooldown(endTime - duration, duration);
            else
                aura.cooldown:Hide();
            end

            -- Set Texture + Count
            aura.icon:SetTexture(iconTexture);
            aura.count:SetFont(GameFontNormal:GetFont(),(addon.db.auras.size / 2),"OUTLINE");
            aura.count:SetText(count and count > 1 and count or "");

            -- Border -- Only shown for debuffs
            if (auraType == "HARMFUL") then
                local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
                aura.border:SetVertexColor(color.r,color.g,color.b);
                aura.border:Show();
            else
                aura.border:Hide();
            end

            -- Show + Next, Break if exceed max desired rows of aura
            aura:SetSize(addon.db.auras.size, addon.db.auras.size);
            aura:Show();
            auraFrameIndex = (auraFrameIndex + 1);
        end
        queryIndex = (queryIndex + 1);
    end

    -- return the number of auras displayed
    return (auraFrameIndex - startingAuraFrameIndex);
end

-- display buffs and debuffs
local function CheckAuras(tip, unit)
    local auraCount = 0;
    if (addon.db.auras.showBuffs) then
        auraCount = auraCount + DisplayAuras(tip, unit, "HELPFUL", auraCount + 1);
    end
    if (addon.db.auras.showDebuffs) then
        auraCount = auraCount + DisplayAuras(tip, unit, "HARMFUL", auraCount + 1);
    end

    -- hide any unused auras
    for i = (auraCount + 1), #auras do
        auras[i]:Hide();
    end
end

-------------------------------------------------------------

local function strip(text)
    return (text:gsub("%s+([|%x%s]+)<trim>", "%1"))
end

local function ColorBorder(tip, config, raw)
    if (config.coloredBorder and addon.colorfunc[config.coloredBorder]) then
        local r, g, b = addon.colorfunc[config.coloredBorder](raw)
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
    elseif (type(config.coloredBorder) == "string" and config.coloredBorder ~= "default") then
        local r, g, b = addon:GetRGBColor(config.coloredBorder)
        if (r and g and b) then
            LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
        end
    end
end

local function ColorBackground(tip, config, raw)
    local bg = config.background
    if not bg then return end
    if (bg.colorfunc == "default" or bg.colorfunc == "" or bg.colorfunc == "inherit") then
        return
    end
    if (addon.colorfunc[bg.colorfunc]) then
        local r, g, b = addon.colorfunc[bg.colorfunc](raw)
        local a = bg.alpha or 0.5
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, a)
    end
end

local function GrayForDead(tip, config, unit)
    if (config.grayForDead and UnitIsDeadOrGhost(unit)) then
        local line, text
        LibEvent:trigger("tooltip.style.border.color", tip, 0.6, 0.6, 0.6)
        LibEvent:trigger("tooltip.style.background", tip, 0.1, 0.1, 0.1)
        for i = 1, tip:NumLines() do
            line = _G[tip:GetName() .. "TextLeft" .. i]
            text = (line:GetText() or ""):gsub("|cff%x%x%x%x%x%x", "|cffaaaaaa")
            line:SetTextColor(0.7, 0.7, 0.7)
            line:SetText(text)
        end
    end
end

local function ShowBigFactionIcon(tip, config, raw)
    if (config.elements.factionBig and config.elements.factionBig.enable and tip.BigFactionIcon and (raw.factionGroup=="Alliance" or raw.factionGroup == "Horde")) then
        tip.BigFactionIcon:Show()
        tip.BigFactionIcon:SetTexture("Interface\\Timer\\".. raw.factionGroup .."-Logo")
        tip:Show()
        tip:SetMinimumWidth(tip:GetWidth() + 20)
    end
end

local function PlayerCharacter(tip, unit, config, raw)
    local data = addon:GetUnitData(unit, config.elements, raw)
    addon:HideLines(tip, 2, tip:NumLines())
    addon:HideLine(tip, "^"..LEVEL)
    addon:HideLine(tip, "^"..FACTION_ALLIANCE)
    addon:HideLine(tip, "^"..FACTION_HORDE)
    addon:HideLine(tip, "^"..PVP)
    for i, v in ipairs(data) do
        addon:GetLine(tip,i):SetText(strip(table.concat(v, " ")))
    end
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    ShowBigFactionIcon(tip, config, raw)
end

local function NonPlayerCharacter(tip, unit, config, raw)
    local levelLine = addon:FindLine(tip, "^"..LEVEL)
    if (levelLine or tip:NumLines() > 1) then
        local data = addon:GetUnitData(unit, config.elements, raw)
        local titleLine = addon:GetNpcTitle(tip)
        local increase = 0
        for i, v in ipairs(data) do
            if (i == 1) then
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            end
            if (i == 2) then
                if (config.elements.npcTitle.enable and titleLine) then
                    titleLine:SetText(addon:FormatData(titleLine:GetText(), config.elements.npcTitle, raw))
                    increase = 1
                end
                i = i + increase
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            elseif ( i > 2) then
                i = i + increase
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            end
        end
    end
    addon:HideLine(tip, "^"..LEVEL)
    addon:HideLine(tip, "^"..PVP)
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    ShowBigFactionIcon(tip, config, raw)
end

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    local raw = addon:GetUnitInfo(unit)
    if (UnitIsPlayer(unit)) then
        PlayerCharacter(tip, unit, addon.db.unit.player, raw)
    else
        NonPlayerCharacter(tip, unit, addon.db.unit.npc, raw)
    end
    CheckAuras(tip, unit)
end)
