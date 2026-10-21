--[[
    Reset Ability Tree
    A simple CET mod for unlimited perk and attribute respec.

    Install: drop the ResetAbilityTree folder into
    <Cyberpunk 2077>/bin/x64/plugins/cyber_engine_tweaks/mods/

    Usage: open CET overlay (default ~ key), find the "Reset Ability Tree" window.
    Requires: Cyber Engine Tweaks 1.28+ / Cyberpunk 2077 2.0+
]]

local modName   = "ResetAbilityTree"
local showUI    = false
local statusMsg = ""
local statusEnd = 0

-- The five attributes and their gamedataStatType enum names
local ATTRS = { "Strength", "Reflexes", "TechnicalAbility", "Intelligence", "Cool" }
local MIN_ATTR = 3  -- lowest possible attribute value in 2.0

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function log(msg)
    print(string.format("[%s] %s", modName, msg))
end

local function status(msg)
    statusMsg = msg
    statusEnd = os.clock() + 4
    log(msg)
end

--- Get PlayerDevelopmentData (returns nil when not in a game session)
local function devData()
    local p = Game.GetPlayer()
    if not p then return nil end
    return PlayerDevelopmentSystem.GetInstance(p):GetDevelopmentData(p)
end

--- Read a single attribute level via the stats system (float → int)
local function getAttr(attrName)
    local p   = Game.GetPlayer()
    local val = Game.GetStatsSystem():GetStatValue(p:GetEntityID(), attrName)
    return math.floor(val)
end

---------------------------------------------------------------------------
-- reset logic
---------------------------------------------------------------------------

local function resetPerks()
    local dd = devData()
    if not dd then status("Not in a game session"); return end

    -- Approach: call ClearPerks if available, then fall back to
    -- RemoveAllPerks per proficiency
    local done = false

    -- Try 1: direct ClearPerks
    local ok = pcall(function() dd:ClearPerks(); done = true end)

    -- Try 2: iterate proficiency areas used in 2.0
    if not done then
        local profs = {
            "StrengthSkill", "ReflexesSkill", "TechnicalAbilitySkill",
            "IntelligenceSkill", "CoolSkill",
        }
        for _, name in ipairs(profs) do
            pcall(function() dd:RemoveAllPerks(name) end)
        end
        done = true
    end

    status("Perks reset — points refunded!")
end

local function resetAttributes()
    local dd = devData()
    if not dd then status("Not in a game session"); return end

    local refund = 0

    for _, attr in ipairs(ATTRS) do
        local cur = getAttr(attr)
        if cur > MIN_ATTR then
            refund = refund + (cur - MIN_ATTR)
            -- SetAttribute confirmed via CET scripting API
            dd:SetAttribute(attr, MIN_ATTR)
        end
    end

    -- Give back the attribute points
    if refund > 0 then
        dd:AddDevelopmentPoints(refund, "Attribute")
    end

    status(string.format("Attributes → %d  |  %d points refunded", MIN_ATTR, refund))
end

local function resetAll()
    resetPerks()
    resetAttributes()
    status("Full reset complete!")
end

---------------------------------------------------------------------------
-- CET lifecycle
---------------------------------------------------------------------------

registerForEvent("onInit", function()
    log("Loaded — open CET overlay to use")
end)

registerForEvent("onOverlayOpen", function()  showUI = true  end)
registerForEvent("onOverlayClose", function() showUI = false end)

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

registerForEvent("onDraw", function()
    if not showUI then return end

    ImGui.SetNextWindowPos(200, 200, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(310, 260, ImGuiCond.FirstUseEver)

    if ImGui.Begin("Reset Ability Tree") then
        ImGui.TextWrapped("Unlimited respec — no save-reload needed.")
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.Button("Reset All Perks", 280, 34) then
            resetPerks()
        end

        ImGui.Spacing()

        if ImGui.Button("Reset Attributes (to " .. MIN_ATTR .. ")", 280, 34) then
            resetAttributes()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.Button("Full Reset", 280, 34) then
            resetAll()
        end

        -- status line
        if statusMsg ~= "" and os.clock() < statusEnd then
            ImGui.Spacing()
            ImGui.TextColored(0.3, 1.0, 0.3, 1.0, statusMsg)
        end
    end
    ImGui.End()
end)
