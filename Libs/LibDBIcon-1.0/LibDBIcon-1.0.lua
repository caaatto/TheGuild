-- Embedded LibDBIcon-1.0 implementation for ForeverCodex.
-- Minimap positioning, shape handling, dragging, hide/show and lock state live
-- entirely in this library; ForeverCodex itself contains no minimap geometry.
local MAJOR, MINOR = "LibDBIcon-1.0", 101
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local LDB = LibStub("LibDataBroker-1.1", true)
if not LDB then error(MAJOR .. " requires LibDataBroker-1.1") end

lib.objects = lib.objects or {}
lib.radius = lib.radius or 5

local minimapShapes = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local rad, cos, sin, sqrt = math.rad, math.cos, math.sin, math.sqrt
local max, min, deg = math.max, math.min, math.deg
local atan2 = math.atan2 or function(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function updatePosition(button, position)
    if not button or not Minimap then return end
    local angle = rad(tonumber(position) or 220)
    local x, y = cos(angle), sin(angle)
    local q = 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end

    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local quadrants = minimapShapes[shape] or minimapShapes.ROUND
    local w = (Minimap:GetWidth() / 2) + lib.radius
    local h = (Minimap:GetHeight() / 2) + lib.radius

    if quadrants[q] then
        x, y = x * w, y * h
    else
        local diagW = sqrt(2 * w * w) - 10
        local diagH = sqrt(2 * h * h) - 10
        x = max(-w, min(x * diagW, w))
        y = max(-h, min(y * diagH, h))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function updateIcon(button)
    local obj = button and button.dataObject
    if not obj or not button.icon then return end
    button.icon:SetTexture(obj.icon)
    local coords = obj.iconCoords
    if coords then
        button.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        button.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    end
end

local function stopDrag(button)
    if not button then return end
    button:SetScript("OnUpdate", nil)
    button.isMoving = nil
    button:UnlockHighlight()
end

local function createButton(name, object, db)
    local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button.dataObject = object
    button.db = db or {}

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    button.icon = icon
    updateIcon(button)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(self, mouseButton)
        local obj = self.dataObject
        if obj and obj.OnClick then obj.OnClick(self, mouseButton) end
    end)

    button:SetScript("OnEnter", function(self)
        if self.isMoving then return end
        local obj = self.dataObject
        if obj and obj.OnTooltipShow then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            obj.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        elseif obj and obj.OnEnter then
            obj.OnEnter(self)
        end
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        local obj = self.dataObject
        if obj and obj.OnLeave then obj.OnLeave(self) end
    end)

    button:SetScript("OnDragStart", function(self)
        if self.db and self.db.lock then return end
        self.isMoving = true
        self:LockHighlight()
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function(btn)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            if not mx or not my or not px or not py then return end
            local scale = Minimap:GetEffectiveScale() or 1
            px, py = px / scale, py / scale
            local pos = deg(atan2(py - my, px - mx)) % 360
            btn.db.minimapPos = pos
            updatePosition(btn, pos)
        end)
    end)
    button:SetScript("OnDragStop", stopDrag)
    button:SetScript("OnHide", stopDrag)

    lib.objects[name] = button
    updatePosition(button, button.db.minimapPos)
    if button.db.hide then button:Hide() else button:Show() end
    return button
end

function lib:Register(name, object, db)
    if self.objects[name] then return self.objects[name] end
    assert(type(name) == "string" and name ~= "", "LibDBIcon:Register requires a name")
    assert(type(object) == "table" and object.icon, "LibDBIcon:Register requires an LDB object with an icon")
    return createButton(name, object, db or {})
end

function lib:IsRegistered(name)
    return self.objects[name] ~= nil
end

function lib:GetMinimapButton(name)
    return self.objects[name]
end

function lib:Refresh(name, db)
    local button = self.objects[name]
    if not button then return end
    if db then button.db = db end
    updateIcon(button)
    updatePosition(button, button.db and button.db.minimapPos)
    if button.db and button.db.hide then button:Hide() else button:Show() end
end

function lib:Show(name)
    local button = self.objects[name]
    if not button then return end
    button.db.hide = false
    updatePosition(button, button.db.minimapPos)
    button:Show()
end

function lib:Hide(name)
    local button = self.objects[name]
    if not button then return end
    button.db.hide = true
    button:Hide()
end

function lib:Lock(name)
    local button = self.objects[name]
    if not button then return end
    button.db.lock = true
    stopDrag(button)
end

function lib:Unlock(name)
    local button = self.objects[name]
    if not button then return end
    button.db.lock = false
end

-- Re-anchor after login/world transitions in case the minimap size/shape changed.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function()
    for _, button in pairs(lib.objects) do
        updatePosition(button, button.db and button.db.minimapPos)
    end
end)
