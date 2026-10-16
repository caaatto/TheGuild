local TG = TheGuild
local L = TG.L

-- Proximity voice on top of the Blizzard guild voice channel. Everyone sits in
-- the same channel, this client turns each member up or down by distance and by
-- voice group, like the proximity mods for Minecraft do it.

local NS_GROUP, NS_MEMBER = "vgroup", "vmem"
local MAX_NAME = 30
local TICK = 1
local FULL = 100

local Voice = TG:NewModule("Voice", {
    title = L["Voice"],
    desc = L["Proximity voice and voice groups on the Blizzard guild voice channel."],
    order = 26,
    defaults = { mode = "proximity", nearRange = 30, farRange = 90, groupsAlways = true, announce = true },
    charDefaults = { autoJoin = false },
    settings = {
        { key = "mode", type = "select", name = L["Voice mode"], default = "proximity",
          options = { { "all", L["Everyone"] }, { "proximity", L["Proximity"] }, { "group", L["Group only"] } },
          onChange = function(mod) mod:Apply(true) end },
        { key = "nearRange", type = "number", name = L["Full volume up to (yards)"], default = 30, min = 5, max = 200, step = 5, onChange = function(mod) mod:Apply(true) end },
        { key = "farRange", type = "number", name = L["Silent beyond (yards)"], default = 90, min = 10, max = 400, step = 10, onChange = function(mod) mod:Apply(true) end },
        { key = "groupsAlways", type = "boolean", name = L["Group members are always audible"], tooltip = L["Members of your voice group keep full volume no matter how far away they are."], default = true, onChange = function(mod) mod:Apply(true) end },
        { key = "announce", type = "boolean", name = L["Announce group changes in chat"], default = true },
        { key = "autoJoin", scope = "char", type = "boolean", name = L["Join the guild voice channel at login"], default = false },
    },
})

TG.Store:DefinePolicy(NS_GROUP, "any")
TG.Store:DefinePolicy(NS_MEMBER, "self")

Voice.MODES = { { "all", L["Everyone"] }, { "proximity", L["Proximity"] }, { "group", L["Group only"] } }

local applied = {}
local original = {}
local resolved = {}
local speaking = {}

-- Blizzard voice

function Voice:Available()
    if self.demoChannel then return true end
    return type(C_VoiceChat) == "table" and C_VoiceChat.CanPlayerUseVoiceChat ~= nil and C_VoiceChat.CanPlayerUseVoiceChat() == true
end

function Voice:LoggedIn()
    if self.demoChannel then return true end
    return self:Available() and C_VoiceChat.IsLoggedIn() == true
end

local function isLocal(memberID, channelID)
    if Voice.demoChannel then return memberID == 1 end
    return C_VoiceChat.IsMemberLocalPlayer(memberID, channelID)
end

-- The demo hands in a fake channel. Volume calls stay local then.
function Voice:SetDemoChannel(channel)
    self.demoChannel = channel
    wipe(applied)
    wipe(original)
    wipe(resolved)
    wipe(speaking)
    TG:Fire("VOICE_UPDATED")
end

function Voice:SetSpeaking(memberID, on)
    speaking[memberID] = on or nil
    TG:Fire("VOICE_UPDATED")
end

-- Club calls throw while the club list is still loading, so they run guarded.
local function guildStream()
    if type(C_Club) ~= "table" or not C_Club.GetGuildClubId then return nil end
    local clubId = C_Club.GetGuildClubId()
    if not TG.usable(clubId) or not clubId then return nil end
    local guildType = Enum.ClubStreamType and Enum.ClubStreamType.Guild or 1
    local fallback
    for _, stream in ipairs(C_Club.GetStreams(clubId) or {}) do
        if stream.streamType == guildType then return clubId, stream.streamId end
        fallback = fallback or stream.streamId
    end
    return clubId, fallback
end

function Voice:GuildStream()
    local ok, clubId, streamId = pcall(guildStream)
    if not ok then return nil end
    return clubId, streamId
end

function Voice:Channel()
    if self.demoChannel then return self.demoChannel end
    if not self:LoggedIn() then return nil end
    local clubId, streamId = self:GuildStream()
    if not clubId or not streamId then return nil end
    local ok, channel = pcall(C_VoiceChat.GetChannelForCommunityStream, clubId, streamId)
    if not ok or type(channel) ~= "table" then return nil end
    return channel
end

function Voice:JoinPending()
    if self.demoChannel or not self:LoggedIn() or not C_VoiceChat.IsChannelJoinPending then return false end
    local clubId, streamId = self:GuildStream()
    if not clubId or not streamId then return false end
    local channelType = Enum.ChatChannelType and Enum.ChatChannelType.Communities or 2
    local ok, pending = pcall(C_VoiceChat.IsChannelJoinPending, channelType, clubId, streamId)
    return ok and pending == true
end

function Voice:IsJoined()
    return self:Channel() ~= nil
end

function Voice:Join()
    if self.demoChannel then return true end
    if not self:Available() then
        TG:Print(L["Blizzard voice chat is not available on this account."])
        return false
    end
    if not C_VoiceChat.IsLoggedIn() then
        C_VoiceChat.Login()
        self.joinAfterLogin = true
        return true
    end
    local clubId, streamId = self:GuildStream()
    if not clubId or not streamId then
        TG:Print(L["No guild voice channel found."])
        return false
    end
    if C_VoiceChat.GetJoinClubVoiceChannelError then
        local err = C_VoiceChat.GetJoinClubVoiceChannelError(clubId)
        if err ~= nil then
            TG:Print(L["The guild voice channel cannot be joined right now."])
            return false
        end
    end
    C_VoiceChat.RequestJoinAndActivateCommunityStreamChannel(clubId, streamId)
    return true
end

function Voice:Leave()
    local channel = self:Channel()
    self:Restore()
    if channel and not self.demoChannel then C_VoiceChat.LeaveChannel(channel.channelID) end
    TG:Fire("VOICE_UPDATED")
end

-- Groups

function Voice:Groups()
    local counts = {}
    for key, item in pairs(TG.Store:Items(NS_MEMBER)) do
        if type(item.v) == "string" then
            counts[item.v] = counts[item.v] or {}
            table.insert(counts[item.v], key)
        end
    end
    local out = {}
    for id, item in pairs(TG.Store:Items(NS_GROUP)) do
        local v = item.v
        if type(v) == "table" then
            local members = counts[id] or {}
            table.sort(members)
            out[#out + 1] = { id = id, name = v.n or "?", owner = v.o or item.a, time = v.ts or item.t or 0, members = members }
        end
    end
    table.sort(out, function(a, b)
        if #a.members ~= #b.members then return #a.members > #b.members end
        return a.name < b.name
    end)
    return out
end

function Voice:Group(id)
    for _, g in ipairs(self:Groups()) do
        if g.id == id then return g end
    end
    return nil
end

function Voice:GroupOf(key)
    local id = TG.Store:Get(NS_MEMBER, key)
    if type(id) ~= "string" or TG.Store:Get(NS_GROUP, id) == nil then return nil end
    return id
end

function Voice:MyGroup()
    return self:GroupOf(TG.MyName())
end

function Voice:CreateGroup(name)
    name = TG.Trim(name or ""):sub(1, MAX_NAME)
    if name == "" then return nil end
    if not TG.InGuild() or not TG.MyName() then
        TG:Print(L["Voice groups need a guild and a loaded roster."])
        return nil
    end
    local id = ("g%d%d"):format(TG.Now(), math.random(10, 99))
    if not TG.Store:Set(NS_GROUP, id, { n = name, o = TG.MyName(), ts = TG.Now() }) then
        TG:Print(L["The voice group could not be saved."])
        return nil
    end
    self:JoinGroup(id)
    return id
end

function Voice:JoinGroup(id)
    if TG.Store:Get(NS_GROUP, id) == nil then return false end
    if not TG.Store:Set(NS_MEMBER, TG.MyName(), id) then return false end
    self:Apply(true)
    return true
end

function Voice:LeaveGroup()
    local had = self:MyGroup()
    TG.Store:Delete(NS_MEMBER, TG.MyName())
    if had then self:PruneGroup(had) end
    self:Apply(true)
end

function Voice:CanManageGroup(group)
    return group.owner == TG.MyName() or TG.Roster:AmOfficer()
end

function Voice:DeleteGroup(id)
    local group = self:Group(id)
    if not group or not self:CanManageGroup(group) then return false end
    if not TG.Store:Delete(NS_GROUP, id) then return false end
    for _, key in ipairs(group.members) do
        if TG.IsMe(key) or TG.Roster:AmOfficer() then TG.Store:Delete(NS_MEMBER, key) end
    end
    self:Apply(true)
    return true
end

-- Empty groups vanish once the last member left.
function Voice:PruneGroup(id)
    local group = self:Group(id)
    if group and #group.members == 0 then TG.Store:Delete(NS_GROUP, id) end
end

-- Distance and volume

local function worldPosition(mapID, x, y)
    if not mapID or not x or not y or x <= 0 or y <= 0 then return nil end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local instance, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if not TG.usable(instance) or not pos then return nil end
    local wx, wy = pos:GetXY()
    if not TG.usable(wx) or not TG.usable(wy) then return nil end
    return instance, wx, wy
end

function Voice:MyPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not TG.usable(mapID) or not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    if not TG.usable(x) or not TG.usable(y) then return nil end
    return worldPosition(mapID, x, y)
end

-- Distance in yards to a member, nil when either position is unknown or on
-- another continent.
function Voice:Distance(key)
    local map = TG:GetModule("Map")
    if not map or not map.enabled then return nil end
    local peer = map:Peer(key)
    if not peer or not peer.hasPos then return nil end
    local instance, px, py = worldPosition(peer.mapID, peer.x, peer.y)
    if not instance then return nil end
    local myInstance, mx, my = self:MyPosition()
    if not myInstance or myInstance ~= instance then return nil end
    local dx, dy = px - mx, py - my
    return math.sqrt(dx * dx + dy * dy)
end

function Voice:TargetVolume(key)
    local mode = self.db.mode
    if mode == "all" then return FULL end
    local mine = self:MyGroup()
    local sameGroup = mine ~= nil and self:GroupOf(key) == mine
    if sameGroup and (self.db.groupsAlways or mode == "group") then return FULL end
    if mode == "group" then return 0 end
    local distance = self:Distance(key)
    if not distance then return 0 end
    local near, far = self.db.nearRange, math.max(self.db.farRange, self.db.nearRange + 1)
    if distance <= near then return FULL end
    if distance >= far then return 0 end
    return math.floor(FULL * (far - distance) / (far - near) + 0.5)
end

local function resolveMember(memberID, channelID)
    if Voice.demoChannel then return Voice.demoChannel.keys[memberID] end
    local cached = resolved[memberID]
    if cached then return cached end
    local key
    local guid = C_VoiceChat.GetMemberGUID(memberID, channelID)
    if TG.usable(guid) and guid then
        local entry = TG.Roster:GetByGUID(guid)
        key = entry and entry.key
    end
    if not key then
        local name = C_VoiceChat.GetMemberName(memberID, channelID)
        if TG.usable(name) and name then key = TG.Key(name) end
    end
    if key then resolved[memberID] = key end
    return key
end

local function setVolume(memberID, channelID, volume)
    if Voice.demoChannel then applied[memberID] = volume return end
    local location = PlayerLocation and PlayerLocation.CreateFromVoiceID and PlayerLocation:CreateFromVoiceID(memberID, channelID)
    if not location then return end
    if original[memberID] == nil then
        local current = C_VoiceChat.GetMemberVolume and C_VoiceChat.GetMemberVolume(location)
        original[memberID] = TG.usable(current) and tonumber(current) or FULL
    end
    C_VoiceChat.SetMemberVolume(location, volume)
    applied[memberID] = volume
end

function Voice:Apply(force)
    local channel = self:Channel()
    if not channel then return end
    local channelID = channel.channelID
    for _, member in ipairs(channel.members or {}) do
        local memberID = member.memberID
        if not isLocal(memberID, channelID) then
            local key = resolveMember(memberID, channelID)
            local volume = key and self:TargetVolume(key) or (self.db.mode == "all" and FULL or 0)
            if self.db.mode == "all" and original[memberID] then volume = original[memberID] end
            if force or applied[memberID] == nil or math.abs(applied[memberID] - volume) >= 3 then
                setVolume(memberID, channelID, volume)
            end
        end
    end
    TG:Fire("VOICE_UPDATED")
end

-- Puts every member we touched back to the volume they had before.
function Voice:Restore()
    local channel = self:Channel()
    if channel and not self.demoChannel then
        for memberID, volume in pairs(original) do
            local location = PlayerLocation and PlayerLocation.CreateFromVoiceID and PlayerLocation:CreateFromVoiceID(memberID, channel.channelID)
            if location then C_VoiceChat.SetMemberVolume(location, volume) end
        end
    end
    wipe(applied)
    wipe(original)
    wipe(resolved)
end

-- Rows for the panel

function Voice:Members()
    local out = {}
    local channel = self:Channel()
    if not channel then return out end
    for _, member in ipairs(channel.members or {}) do
        local isMe = isLocal(member.memberID, channel.channelID)
        local key = isMe and TG.MyName() or resolveMember(member.memberID, channel.channelID)
        local distance = key and not isMe and self:Distance(key) or nil
        out[#out + 1] = {
            key = key or "?", memberID = member.memberID, isMe = isMe,
            speaking = speaking[member.memberID] or member.isSpeaking == true,
            active = member.isActive ~= false,
            distance = distance,
            volume = isMe and FULL or applied[member.memberID] or FULL,
            group = key and self:GroupOf(key),
        }
    end
    table.sort(out, function(a, b)
        if a.isMe ~= b.isMe then return a.isMe end
        if a.speaking ~= b.speaking then return a.speaking end
        return a.key < b.key
    end)
    return out
end

function Voice:StatusText()
    if not self:Available() then return GRAY_FONT_COLOR:WrapTextInColorCode(L["Blizzard voice chat is not available on this account."]) end
    if not self:LoggedIn() then return L["Voice chat is logged out."] end
    local channel = self:Channel()
    if not channel then
        if self:JoinPending() then return YELLOW_FONT_COLOR:WrapTextInColorCode(L["Join requested, waiting for the voice service."]) end
        return L["Not in the guild voice channel."]
    end
    return GREEN_FONT_COLOR:WrapTextInColorCode(L["In the guild voice channel with %d members"]:format(#(channel.members or {})))
end

function Voice:ModeName()
    for _, m in ipairs(self.MODES) do
        if m[1] == self.db.mode then return m[2] end
    end
    return ""
end

-- Lifecycle

function Voice:OnStoreChanged(ns, key, value)
    if ns ~= NS_GROUP and ns ~= NS_MEMBER then return end
    if ns == NS_MEMBER and self.db.announce and not TG.IsMe(key) then
        local mine = self:MyGroup()
        if mine and value == mine then
            TG:Print(L["%s joined your voice group."], TG.ShortName(key))
        end
    end
    self:Apply(true)
end

function Voice:OnEnable()
    self:RegisterEvent("VOICE_CHAT_CHANNEL_JOINED", function() wipe(resolved) self:Apply(true) end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_REMOVED", function() wipe(applied) wipe(original) wipe(resolved) TG:Fire("VOICE_UPDATED") end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_ADDED", function() self:Apply(true) end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_REMOVED", function(_, memberID)
        applied[memberID] = nil
        original[memberID] = nil
        resolved[memberID] = nil
        speaking[memberID] = nil
        TG:Fire("VOICE_UPDATED")
    end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_SPEAKING_STATE_CHANGED", function(_, memberID, _, isSpeaking)
        speaking[memberID] = isSpeaking == true or nil
        TG:Fire("VOICE_UPDATED")
    end)
    self:RegisterEvent("VOICE_CHAT_LOGIN", function()
        if self.joinAfterLogin then
            self.joinAfterLogin = false
            TG.After(1, function() if self.enabled then self:Join() end end)
        end
        TG:Fire("VOICE_UPDATED")
    end)
    self:RegisterEvent("VOICE_CHAT_LOGOUT", function() wipe(applied) wipe(original) TG:Fire("VOICE_UPDATED") end)
    self:RegisterEvent("VOICE_CHAT_PENDING_CHANNEL_JOIN_STATE", function() TG:Fire("VOICE_UPDATED") end)
    self:RegisterEvent("VOICE_CHAT_ERROR", function(_, platformCode, statusCode)
        TG:Print(L["Voice chat error %s (%s)"], self:StatusName(statusCode), tostring(platformCode))
        TG:Fire("VOICE_UPDATED")
    end)
    self:On("STORE_CHANGED", function(ns, key, value) self:OnStoreChanged(ns, key, value) end)
    self:Ticker(TICK, function() if self.db.mode ~= "all" then self:Apply(false) end end)
    if self.cdb.autoJoin then
        TG.After(20, function() if self.enabled and self:Available() and not self:IsJoined() then self:Join() end end)
    end
end

function Voice:OnDisable()
    self:Restore()
end

function Voice:StatusName(code)
    if Enum.VoiceChatStatusCode then
        for name, value in pairs(Enum.VoiceChatStatusCode) do
            if value == code then return name end
        end
    end
    return tostring(code)
end

-- Prints everything needed to tell why voice does not come up.
function Voice:PrintDiagnostics()
    TG:Print(L["Voice"])
    local lines = {}
    lines[#lines + 1] = ("  C_VoiceChat: %s"):format(type(C_VoiceChat) == "table" and "yes" or "no")
    if type(C_VoiceChat) == "table" then
        lines[#lines + 1] = ("  can use: %s, enabled: %s, logged in: %s, connected: %s"):format(
            tostring(C_VoiceChat.CanPlayerUseVoiceChat and C_VoiceChat.CanPlayerUseVoiceChat()),
            tostring(C_VoiceChat.IsEnabled and C_VoiceChat.IsEnabled()),
            tostring(C_VoiceChat.IsLoggedIn and C_VoiceChat.IsLoggedIn()),
            tostring(C_VoiceChat.IsVoiceChatConnected and C_VoiceChat.IsVoiceChatConnected()))
        if C_VoiceChat.GetCurrentVoiceChatConnectionStatusCode then
            lines[#lines + 1] = ("  connection status: %s"):format(self:StatusName(C_VoiceChat.GetCurrentVoiceChatConnectionStatusCode()))
        end
        if C_VoiceChat.GetActiveVoiceProviderID then
            lines[#lines + 1] = ("  provider: %s"):format(tostring(C_VoiceChat.GetActiveVoiceProviderID()))
        end
    end
    local clubId, streamId = self:GuildStream()
    lines[#lines + 1] = ("  guild club: %s, stream: %s"):format(tostring(clubId), tostring(streamId))
    if clubId and C_VoiceChat.GetJoinClubVoiceChannelError then
        local ok, err = pcall(C_VoiceChat.GetJoinClubVoiceChannelError, clubId)
        lines[#lines + 1] = ("  join error: %s"):format(ok and tostring(err) or "call failed")
    end
    lines[#lines + 1] = ("  join pending: %s"):format(tostring(self:JoinPending()))
    local channel = self:Channel()
    lines[#lines + 1] = ("  channel: %s"):format(channel and ("%s (%d members)"):format(tostring(channel.name), #(channel.members or {})) or "none")
    for _, line in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(line) end
end

TG:RegisterSlash("voice", function(rest)
    local cmd, arg = tostring(rest or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "status" then Voice:PrintDiagnostics()
    elseif cmd == "join" then Voice:Join()
    elseif cmd == "leave" then Voice:Leave()
    elseif cmd == "group" and arg ~= "" then
        for _, g in ipairs(Voice:Groups()) do
            if g.name:lower() == arg:lower() then Voice:JoinGroup(g.id) return end
        end
        Voice:CreateGroup(arg)
    elseif cmd == "leavegroup" then Voice:LeaveGroup()
    else
        TG.Window:ShowTab("voice")
    end
end, L["voice: status, join, leave, group <name>, leavegroup"])
