local _, TG = ...

local frame = CreateFrame("Frame")
local events = {}
local messages = {}
local combatQueue = {}

frame:SetScript("OnEvent", function(_, event, ...)
    local list = events[event]
    if not list then return end
    for i = #list, 1, -1 do
        local h = list[i]
        TG.SafeCall(h.fn, event, ...)
    end
end)

function TG:RegisterEvent(event, fn, owner)
    if not events[event] then
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then
            TG:Debug("unknown event %s", event)
            return false
        end
        events[event] = {}
    end
    table.insert(events[event], { fn = fn, owner = owner })
    return true
end

function TG:UnregisterEvent(event, owner)
    local list = events[event]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].owner == owner then table.remove(list, i) end
    end
    if #list == 0 then
        events[event] = nil
        pcall(frame.UnregisterEvent, frame, event)
    end
end

function TG:UnregisterAllEvents(owner)
    for event in pairs(events) do
        TG:UnregisterEvent(event, owner)
    end
end

function TG:On(message, fn, owner)
    messages[message] = messages[message] or {}
    table.insert(messages[message], { fn = fn, owner = owner })
end

function TG:Off(message, owner)
    local list = messages[message]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].owner == owner then table.remove(list, i) end
    end
end

function TG:OffAll(owner)
    for message in pairs(messages) do TG:Off(message, owner) end
end

function TG:Fire(message, ...)
    local list = messages[message]
    if not list then return end
    for i = #list, 1, -1 do
        local h = list[i]
        if h then TG.SafeCall(h.fn, ...) end
    end
end

function TG:AfterCombat(fn)
    if not InCombatLockdown() then
        TG.SafeCall(fn)
        return
    end
    combatQueue[#combatQueue + 1] = fn
end

TG:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    local queue = combatQueue
    combatQueue = {}
    for _, fn in ipairs(queue) do TG.SafeCall(fn) end
end)
