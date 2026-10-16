-- Lightweight CallbackHandler-1.0 compatible implementation.
local MAJOR, MINOR = "CallbackHandler-1.0", 8
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)
if not CallbackHandler then return end

function CallbackHandler:New(target, registerName, unregisterName, unregisterAllName)
    target = target or {}
    registerName = registerName or "RegisterCallback"
    unregisterName = unregisterName or "UnregisterCallback"
    if unregisterAllName == nil then unregisterAllName = "UnregisterAllCallbacks" end

    local events = {}
    local registry = {}

    function registry:Fire(event, ...)
        local handlers = events[event]
        if not handlers then return end
        for object, method in pairs(handlers) do
            if type(method) == "string" then
                if type(object) == "table" and type(object[method]) == "function" then
                    pcall(object[method], object, event, ...)
                end
            elseif type(method) == "function" then
                pcall(method, event, ...)
            end
        end
    end

    target[registerName] = function(self, event, method)
        assert(type(event) == "string", "event must be a string")
        method = method or event
        events[event] = events[event] or {}
        events[event][self] = method
    end

    target[unregisterName] = function(self, event)
        if events[event] then events[event][self] = nil end
    end

    if unregisterAllName then
        target[unregisterAllName] = function(self)
            for _, handlers in pairs(events) do handlers[self] = nil end
        end
    end

    return registry
end
