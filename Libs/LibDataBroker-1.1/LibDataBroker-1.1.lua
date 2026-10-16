-- Lightweight LibDataBroker-1.1 compatible implementation.
assert(LibStub, "LibDataBroker-1.1 requires LibStub")
local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4)
if not lib then return end
lib.objects = lib.objects or {}
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

function lib:NewDataObject(name, data)
    if self.objects[name] then return self.objects[name] end
    local object = data or {}
    self.objects[name] = object
    self.callbacks:Fire("LibDataBroker_DataObjectCreated", name, object)
    return object
end

function lib:GetDataObjectByName(name) return self.objects[name] end
function lib:DataObjectIterator() return pairs(self.objects) end
function lib:GetNameByDataObject(object)
    for name, obj in pairs(self.objects) do if obj == object then return name end end
end
