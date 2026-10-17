local _, TG = ...
local L = TG.L

local Tutorial = {}
TG.Tutorial = Tutorial

local SYSTEM = "TheGuild"
local defined = {}
local active
local tour

local POINTS = {
    bottom = "BottomEdgeCenter",
    top = "TopEdgeCenter",
    left = "LeftEdgeCenter",
    right = "RightEdgeCenter",
    bottomleft = "BottomEdgeLeft",
    bottomright = "BottomEdgeRight",
    topleft = "TopEdgeLeft",
    topright = "TopEdgeRight",
}

local function seen()
    TG.db.global.tutorials = TG.db.global.tutorials or {}
    return TG.db.global.tutorials
end

function Tutorial:Available()
    return type(HelpTip) == "table" and HelpTip.Show ~= nil and HelpTip.Point ~= nil
end

function Tutorial:Enabled()
    return self:Available() and TG.db.global.tutorialsOff ~= true
end

function Tutorial:Define(id, steps)
    defined[id] = steps
end

function Tutorial:Seen(id)
    return seen()[id] == true
end

local function resolve(target)
    if type(target) == "function" then return target() end
    return target
end

local function finish(run, completed, closed)
    if completed then seen()[run.id] = true end
    if active == run then active = nil end
    if closed and tour then
        for _, id in ipairs(tour.order) do seen()[id] = true end
        seen().tour = true
        tour = nil
        return
    end
    if completed and run.next then run.next() end
end

local function showStep(run)
    local step = run.steps[run.index]
    if not step then
        finish(run, true)
        return
    end
    local target = resolve(step.target)
    if not target or (target.IsShown and not target:IsShown()) then
        run.index = run.index + 1
        showStep(run)
        return
    end
    run.target = target
    if target.HookScript and not target.tgTutorialHook then
        target.tgTutorialHook = true
        target:HookScript("OnHide", function(t) Tutorial:TargetHidden(t) end)
    end
    local last = run.index == #run.steps and not (tour and tour.index < #tour.order)
    local info = {
        text = step.text,
        buttonStyle = last and HelpTip.ButtonStyle.GotIt or HelpTip.ButtonStyle.Next,
        targetPoint = HelpTip.Point[POINTS[step.point or "bottom"] or "BottomEdgeCenter"],
        alignment = HelpTip.Alignment.Center,
        offsetX = step.offsetX or 0,
        offsetY = step.offsetY or 0,
        system = SYSTEM,
        autoEdgeFlipping = true,
        autoHorizontalSlide = true,
        onAcknowledgeCallback = function()
            if active ~= run then return end
            run.index = run.index + 1
            TG.After(0.05, function() if active == run then showStep(run) end end)
        end,
        onHideCallback = function(acknowledged, _, reason)
            if acknowledged or active ~= run or run.navigating then return end
            if reason == HelpTip.HideReason.Closed then
                finish(run, true, true)
            else
                finish(run, false)
            end
        end,
    }
    run.info = info
    HelpTip:Show(UIParent, info, target)
end

function Tutorial:TargetHidden(target)
    local run = active
    if not run or run.target ~= target then return end
    TG.After(0.05, function()
        if active ~= run or run.target ~= target or run.navigating or target:IsVisible() then return end
        run.navigating = true
        if HelpTip.HideAllSystem then HelpTip:HideAllSystem(SYSTEM) end
        run.navigating = nil
        run.index = run.index + 1
        showStep(run)
    end)
end

function Tutorial:Start(id, force, next, inTour)
    local steps = defined[id]
    if not steps or not self:Enabled() then return false end
    if tour and not inTour then return false end
    if not force and seen()[id] then return false end
    if active then
        if active.id == id then return false end
        active = nil
        if self:Available() and HelpTip.HideAllSystem then HelpTip:HideAllSystem(SYSTEM) end
    end
    active = { id = id, steps = steps, index = 1, next = next }
    showStep(active)
    return true
end

function Tutorial:Stop()
    active = nil
    tour = nil
    if self:Available() and HelpTip.HideAllSystem then HelpTip:HideAllSystem(SYSTEM) end
end

function Tutorial:Touring()
    return tour ~= nil
end

local function tourNext()
    if not tour then return end
    tour.index = tour.index + 1
    local id = tour.order[tour.index]
    if not id then
        seen().tour = true
        tour = nil
        TG.Window:SelectTab(1)
        return
    end
    local current = tour
    if id == "window" then
        if not TG.Window:IsShown() then TG.Window:Toggle() end
    elseif id ~= "hud" then
        for index, tab in ipairs(TG.Window:Tabs()) do
            if tab.id == id then TG.Window:SelectTab(index) end
        end
    end
    if tour ~= current then return end
    if not Tutorial:Start(id, true, tourNext, true) then tourNext() end
end

function Tutorial:Tour()
    if not self:Enabled() then return false end
    self:Stop()
    local order = { "hud", "window" }
    for _, tab in ipairs(TG.Window:Tabs()) do order[#order + 1] = tab.id end
    tour = { order = order, index = 0 }
    tourNext()
    return true
end

function Tutorial:Active()
    return active and active.id or nil
end

function Tutorial:Reset()
    wipe(seen())
    TG.db.global.tutorialsOff = nil
    self:Stop()
end

function Tutorial:ShowForTab(id)
    if not self:Enabled() or tour then return end
    if not self:Seen("tour") then
        self:Tour()
    else
        self:Start(id)
    end
end

function Tutorial:MaybeTour()
    if not self:Enabled() or tour or self:Seen("tour") then return false end
    return self:Tour()
end

TG:On("WINDOW_TAB", function(id) Tutorial:ShowForTab(id) end)
TG:On("MODULE_DISABLED", function() Tutorial:Stop() end)
