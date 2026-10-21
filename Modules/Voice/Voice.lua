local TG = TheGuild
local L = TG.L

local NS_GROUP, NS_MEMBER, NS_QUIET = "vgroup", "vmem", "vquiet"
local MAX_NAME = 30
local TICK = 1
local FULL = 100
local PARTY_GROUP_TTL = 8 * 3600
local PARTY_GROUP_GRACE = 120

local Voice = TG:NewModule("Voice", {
    title = L["Voice"],
    desc = L["Proximity voice and voice groups on the Blizzard guild voice channel."],
    order = 26,
    defaults = { mode = "proximity", nearRange = 30, farRange = 90, announce = true, partyVoice = false, hud = true, hudLock = false, hudList = true, hideToasts = true },
    charDefaults = { autoJoin = false },
    settings = {
        { type = "binding", action = "THEGUILD_VOICE_MUTE" },
        { key = "mode", type = "select", name = L["Voice mode"], default = "proximity",
          options = { { "proximity", L["Group and proximity"] }, { "solo", L["Proximity only"] }, { "group", L["Group only"] } },
          tooltip = L["Group and proximity: your voice group is always audible, everyone else by distance. Proximity only: you still hear your group, but your group hears you only when you are close, like everyone else. Group only: nobody but your voice group."],
          onChange = function(mod) mod:SetMode(mod.db.mode) end },
        { key = "nearRange", type = "number", name = L["Full volume up to (yards)"], default = 30, min = 5, max = 200, step = 5, onChange = function(mod) mod:Apply(true) end },
        { key = "farRange", type = "number", name = L["Silent beyond (yards)"], default = 90, min = 10, max = 400, step = 10, onChange = function(mod) mod:Apply(true) end },
        { key = "partyVoice", type = "boolean", name = L["Turn your party into a voice group"],
          tooltip = L["Guild members in your party or raid share a voice group automatically. Voice stays on the guild channel, party voice is not used."], default = true,
          onChange = function(mod) mod:SyncPartyGroup() end },
        { key = "announce", type = "boolean", name = L["Announce group changes in chat"], default = true },
        { key = "autoJoin", scope = "char", type = "boolean", name = L["Join the guild voice channel at login"], default = false },
        { key = "hud", type = "boolean", name = L["Show the microphone button"], tooltip = L["A small movable button that shows whether you are muted. Left click mutes, right click opens the menu."], default = true,
          onChange = function(mod) mod:RefreshHud() end },
        { key = "hudLock", type = "boolean", name = L["Lock the microphone button"], default = false },
        { key = "hudList", type = "boolean", name = L["Show who is in voice below the microphone button"], default = true, onChange = function(mod) mod:RefreshHud() end },
        { key = "hideToasts", type = "boolean", name = L["Hide the speaking notifications of the game client"], tooltip = L["The client shows a small toast above the chat whenever somebody talks. The microphone button and its list replace it."], default = true,
          onChange = function(mod) mod:ApplyToasts() end },
    },
})

TG.Store:DefinePolicy(NS_GROUP, "any", 30 * 86400, TG.Store.Shape({ n = "string", o = "string", ts = "number", p = "boolean?" }))
TG.Store:DefinePolicy(NS_MEMBER, "self", 30 * 86400, TG.Store.Text(40))
TG.Store:DefinePolicy(NS_QUIET, "self", 3 * 86400, function(v) return v == true end)

Voice.MODES = { { "proximity", L["Group and proximity"] }, { "solo", L["Proximity only"] }, { "group", L["Group only"] } }

local applied = {}
local original = {}
local resolved = {}
local speaking = {}
local energy = {}

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

function Voice:SetDemoChannel(channel)
    self.demoChannel = channel
    wipe(applied)
    wipe(original)
    wipe(resolved)
    wipe(speaking)
    TG:Fire("VOICE_UPDATED")
end

function Voice:LocalMember()
    local channel = self:ActiveChannel()
    if not channel then return nil end
    for _, member in ipairs(channel.members or {}) do
        if isLocal(member.memberID, channel.channelID) then return member, channel end
    end
    return nil, channel
end

function Voice:PushToTalkHeld()
    if self.demoChannel or not self:Available() then return false end
    if self.pttPressed ~= nil then return self.pttPressed end
    local ptt = Enum.CommunicationMode and Enum.CommunicationMode.PushToTalk or 0
    if not C_VoiceChat.GetCommunicationMode or C_VoiceChat.GetCommunicationMode() ~= ptt then return false end
    return C_VoiceChat.GetPTTButtonPressedState ~= nil and C_VoiceChat.GetPTTButtonPressedState() == true
end

function Voice:IsSpeaking()
    if self:PushToTalkHeld() then return true end
    local member = self:LocalMember()
    if not member then return false end
    if speaking[member.memberID] or member.isSpeaking == true then return true end
    return (energy[member.memberID] or 0) > 0 or (tonumber(member.energy) or 0) > 0
end

function Voice:EnsureActive(channel)
    if self.demoChannel or not channel then return end
    local now = GetTime()
    if self.lastActivate and now - self.lastActivate < 10 then return end
    local active = C_VoiceChat.GetActiveChannelID and C_VoiceChat.GetActiveChannelID()
    if channel.isActive == false or (TG.usable(active) and active ~= channel.channelID) then
        self.lastActivate = now
        if C_VoiceChat.ActivateChannel then C_VoiceChat.ActivateChannel(channel.channelID) end
    end
end

function Voice:SetSpeaking(memberID, on)
    speaking[memberID] = on or nil
    TG:Fire("VOICE_UPDATED")
end

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

function Voice:ActiveChannel()
    if self.demoChannel then return self.demoChannel end
    local guild = self:Channel()
    if guild then return guild end
    if not self:LoggedIn() or not C_VoiceChat.GetActiveChannelID or not C_VoiceChat.GetChannel then return nil end
    local id = C_VoiceChat.GetActiveChannelID()
    if not TG.usable(id) or not id then return nil end
    local ok, channel = pcall(C_VoiceChat.GetChannel, id)
    if ok and type(channel) == "table" then return channel end
    return nil
end

local function trace(self, event, ...)
    if not self.debug then return end
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    DEFAULT_CHAT_FRAME:AddMessage(("%.2f %s %s"):format(GetTime() % 1000, event, table.concat(parts, " ")))
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
    self.previousGroup = nil
    if self:MyGroup() then self:LeaveGroup() end
    if TG.MyName() and TG.Store:Get(NS_QUIET, TG.MyName()) ~= nil then TG.Store:Delete(NS_QUIET, TG.MyName()) end
    self:Restore()
    if channel and not self.demoChannel then C_VoiceChat.LeaveChannel(channel.channelID) end
    TG:Fire("VOICE_UPDATED")
end

function Voice:Groups()
    local counts = {}
    for key, item in pairs(TG.Store:Items(NS_MEMBER)) do
        if type(item.v) == "string" then
            counts[item.v] = counts[item.v] or {}
            table.insert(counts[item.v], key)
        end
    end
    local out = {}
    local ready = TG.Roster:IsReady()
    local party = TG.GroupMembers()
    for id, item in pairs(TG.Store:Items(NS_GROUP)) do
        local v = item.v
        if type(v) == "table" then
            local all = counts[id] or {}
            table.sort(all)
            local members = {}
            for _, key in ipairs(all) do
                local entry = TG.Roster:Get(key)
                if TG.IsMe(key) or not ready or (entry and entry.online) or party[key] then members[#members + 1] = key end
            end
            out[#out + 1] = { id = id, name = v.n or "?", owner = v.o or item.a, time = v.ts or item.t or 0, members = members, online = #members, total = #all, party = v.p == true }
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

function Voice:CreateGroup(name, party)
    name = TG.Trim(name or ""):sub(1, MAX_NAME)
    if name == "" then return nil end
    if not TG.InGuild() or not TG.MyName() then
        TG:Print(L["Voice groups need a guild and a loaded roster."])
        return nil
    end
    if not party then
        for _, g in ipairs(self:Groups()) do
            if not g.party and g.name:lower() == name:lower() then
                self:JoinGroup(g.id)
                return g.id
            end
        end
    end
    local id = ("%s%d%02d%s"):format(party and "p" or "g", TG.Now(), math.random(0, 99), TG.ShortName(TG.MyName()))
    if not TG.Store:Set(NS_GROUP, id, { n = name, o = TG.MyName(), ts = TG.Now(), p = party or nil }) then
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
    local wasSyncing = self.syncing
    self.syncing = true
    TG.Store:Delete(NS_MEMBER, TG.MyName())
    if had then self:PruneGroup(had) end
    self.syncing = wasSyncing
    self:Apply(true)
end

function Voice:InActiveParty(group)
    if not group.party or group.id ~= self:MyGroup() then return false end
    local _, n = self:PartyKeys()
    return n > 0
end

function Voice:CanManageGroup(group)
    if self:InActiveParty(group) then return false end
    return group.owner == TG.MyName()
end

function Voice:DeleteGroup(id)
    local group = self:Group(id)
    if not group or not self:CanManageGroup(group) then return false end
    local wasSyncing = self.syncing
    self.syncing = true
    local officer = TG.Roster:AmOfficer()
    for _, key in ipairs(group.members) do
        if TG.IsMe(key) or officer then TG.Store:Delete(NS_MEMBER, key) end
    end
    local ok = TG.Store:Delete(NS_GROUP, id)
    self.syncing = wasSyncing
    self:Apply(true)
    return ok
end

function Voice:PruneGroup(id)
    local group = self:Group(id)
    if group and group.total == 0 then TG.Store:Delete(NS_GROUP, id) end
end

function Voice:PartyKeys()
    local keys = {}
    local n = GetNumGroupMembers()
    if not TG.usable(n) or not n or n == 0 then return keys, 0 end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (IsInRaid() and n or n - 1) do
        local guid = UnitGUID(prefix .. i)
        local entry = TG.usable(guid) and guid and TG.Roster:GetByGUID(guid)
        if entry and not TG.IsMe(entry.key) then keys[#keys + 1] = entry.key end
    end
    return keys, n
end

local function staleParty(g, now)
    if not g.party then return false end
    local age = now - (g.time or 0)
    return age > PARTY_GROUP_TTL or (g.online == 0 and age > PARTY_GROUP_GRACE)
end

local function partyGroupFor(keys)
    local best
    local now = TG.Now()
    for _, g in ipairs(Voice:Groups()) do
        if g.party and not staleParty(g, now) then
            for _, member in ipairs(g.members) do
                local inParty = TG.IsMe(member)
                for _, key in ipairs(keys) do if key == member then inParty = true end end
                if inParty and (not best or g.id < best.id) then best = g break end
            end
        end
    end
    return best
end

local function shouldCreatePartyGroup(keys)
    local me = TG.MyName()
    for _, key in ipairs(keys) do
        if TG.Comm:HasAddon(key) and key < me then return false end
    end
    return true
end

local function syncPartyGroup(self)
    if not self:IsJoined() then return end
    local keys, n = self:PartyKeys()
    local mine = self:MyGroup()
    local now = TG.Now()
    for _, g in ipairs(self:Groups()) do
        if g.id ~= mine and staleParty(g, now) then TG.Store:Delete(NS_GROUP, g.id) end
    end
    local mineGroup = mine and self:Group(mine)
    if n == 0 then
        if mineGroup and mineGroup.party then
            self:LeaveGroup()
            if self.previousGroup and TG.Store:Get(NS_GROUP, self.previousGroup) ~= nil then self:JoinGroup(self.previousGroup) end
        end
        self.previousGroup = nil
        return
    end
    local best = partyGroupFor(keys)
    if best then
        if mine ~= best.id then
            if not (mineGroup and mineGroup.party) then self.previousGroup = mine end
            self:JoinGroup(best.id)
            if mineGroup and mineGroup.party then self:PruneGroup(mine) end
        end
        return
    end
    if not shouldCreatePartyGroup(keys) then return end
    if not (mineGroup and mineGroup.party) then self.previousGroup = mine end
    self:CreateGroup(L["Party of %s"]:format(TG.ShortName(TG.MyName())), true)
end

function Voice:SyncPartyGroup()
    if self.syncing or not self.enabled or not self.db.partyVoice or not TG.InGuild() or not TG.MyName() then return end
    self.syncing = true
    TG.SafeCall(syncPartyGroup, self)
    self.syncing = nil
end

function Voice:KeepGuildChannelActive(channelID)
    if self.demoChannel or not self.db.partyVoice then return end
    local channel = self:Channel()
    if not channel or channel.channelID == channelID then return end
    local other = C_VoiceChat.GetChannel and C_VoiceChat.GetChannel(channelID)
    if type(other) ~= "table" or other.channelType == Enum.ChatChannelType.Communities then return end
    if C_VoiceChat.ActivateChannel then C_VoiceChat.ActivateChannel(channel.channelID) end
end

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

function Voice:IsQuiet(key)
    return TG.Store:Get(NS_QUIET, key) == true
end

function Voice:TargetVolume(key)
    local mine = self:MyGroup()
    if mine ~= nil and self:GroupOf(key) == mine and not self:IsQuiet(key) then return FULL end
    if self:Mode() == "group" then return 0 end
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
        local ok, current = pcall(C_VoiceChat.GetMemberVolume, location)
        if not ok then return end
        original[memberID] = TG.usable(current) and tonumber(current) or FULL
    end
    if not pcall(C_VoiceChat.SetMemberVolume, location, volume) then return end
    applied[memberID] = volume
end

function Voice:Apply(force)
    local channel = self:Channel()
    if not channel then return end
    local channelID = channel.channelID
    self:EnsureActive(channel)
    for _, member in ipairs(channel.members or {}) do
        local memberID = member.memberID
        if not isLocal(memberID, channelID) then
            local key = resolveMember(memberID, channelID)
            local volume = key and self:TargetVolume(key) or 0
            if force or applied[memberID] == nil or math.abs(applied[memberID] - volume) >= 3 then
                setVolume(memberID, channelID, volume)
            end
        end
    end
    TG:Fire("VOICE_UPDATED")
end

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

function Voice:Members()
    local out = {}
    local channel = self:ActiveChannel()
    if not channel then return out end
    for _, member in ipairs(channel.members or {}) do
        local isMe = isLocal(member.memberID, channel.channelID)
        local key = isMe and TG.MyName() or resolveMember(member.memberID, channel.channelID)
        local distance = key and not isMe and self:Distance(key) or nil
        local talking = speaking[member.memberID] or member.isSpeaking == true
        if isMe and (self:IsMuted() or self:IsSilenced()) then talking = false end
        out[#out + 1] = {
            key = key or "?", memberID = member.memberID, isMe = isMe,
            speaking = talking,
            active = member.isActive ~= false,
            muted = member.isMutedForAll == true or member.isSilenced == true,
            distance = distance,
            volume = isMe and FULL or applied[member.memberID] or FULL,
            group = key and self:GroupOf(key),
            quiet = key ~= nil and not isMe and self:IsQuiet(key),
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

function Voice:Mode()
    if self.db.mode ~= "group" and self.db.mode ~= "solo" then self.db.mode = "proximity" end
    return self.db.mode
end

function Voice:PublishQuiet()
    local me = TG.MyName()
    if not me or not TG.InGuild() then return end
    local quiet = self:Mode() == "solo"
    if quiet and not self:IsQuiet(me) then
        TG.Store:Set(NS_QUIET, me, true)
    elseif not quiet and TG.Store:Get(NS_QUIET, me) ~= nil then
        TG.Store:Delete(NS_QUIET, me)
    end
end

function Voice:SetMode(mode)
    self.db.mode = mode
    self:Mode()
    self:PublishQuiet()
    self:Apply(true)
end

function Voice:ModeName()
    local mode = self:Mode()
    for _, m in ipairs(self.MODES) do
        if m[1] == mode then return m[2] end
    end
    return ""
end

function Voice:OnStoreChanged(ns, key, value)
    if ns ~= NS_GROUP and ns ~= NS_MEMBER and ns ~= NS_QUIET then return end
    if ns ~= NS_QUIET and not TG.IsMe(key) then self:SyncPartyGroup() end
    if ns == NS_MEMBER and self.db.announce and not TG.IsMe(key) then
        local mine = self:MyGroup()
        if mine and value == mine then
            TG:Print(L["%s joined your voice group."], TG.ShortName(key))
        end
    end
    self:Apply(false)
end

local DEFAULT_TOASTS = { "VoiceActivityNotificationTemplate" }

function Voice:ApplyToasts()
    local manager = VoiceActivityManager
    if type(manager) ~= "table" or type(manager.notificationTemplates) ~= "table" then return end
    local templates = manager.notificationTemplates
    if self.enabled and self.db.hideToasts then
        if #templates > 0 then
            self.savedToasts = { unpack(templates) }
            wipe(templates)
        end
    elseif #templates == 0 then
        for i, template in ipairs(self.savedToasts or DEFAULT_TOASTS) do templates[i] = template end
    end
end

function Voice:OnEnable()
    self:ApplyToasts()
    self:RegisterEvent("VOICE_CHAT_CHANNEL_JOINED", function(...) trace(self, ...) wipe(resolved) self:Apply(true) TG:Fire("VOICE_UPDATED") end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_REMOVED", function() wipe(applied) wipe(original) wipe(resolved) TG:Fire("VOICE_UPDATED") end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_ADDED", function() self:Apply(true) end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_REMOVED", function(_, memberID)
        applied[memberID] = nil
        energy[memberID] = nil
        original[memberID] = nil
        resolved[memberID] = nil
        speaking[memberID] = nil
        TG:Fire("VOICE_UPDATED")
    end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_SPEAKING_STATE_CHANGED", function(event, memberID, channelID, isSpeaking)
        trace(self, event, memberID, channelID, isSpeaking)
        speaking[memberID] = isSpeaking == true or nil
        TG:Fire("VOICE_UPDATED")
    end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_ENERGY_CHANGED", function(event, memberID, channelID, level)
        local before = (energy[memberID] or 0) > 0
        if before ~= ((tonumber(level) or 0) > 0) then trace(self, event, memberID, channelID, level) end
        energy[memberID] = tonumber(level) or 0
        if before ~= (energy[memberID] > 0) then TG:Fire("VOICE_UPDATED") end
    end)
    self:RegisterEvent("VOICE_CHAT_PTT_BUTTON_PRESSED_STATE_CHANGED", function(event, pressed)
        trace(self, event, pressed)
        self.pttPressed = pressed == true
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
    self:RegisterEvent("VOICE_CHAT_CHANNEL_ACTIVATED", function(event, channelID) trace(self, event, channelID) self:KeepGuildChannelActive(channelID) TG:Fire("VOICE_UPDATED") end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_DEACTIVATED", function(event, channelID) trace(self, event, channelID) TG:Fire("VOICE_UPDATED") end)
    self:RegisterEvent("VOICE_CHAT_CHANNEL_TRANSMIT_CHANGED", function(event, channelID, transmitting) trace(self, event, channelID, transmitting) TG:Fire("VOICE_UPDATED") end)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function() self:SyncPartyGroup() end)
    self:RegisterEvent("GROUP_LEFT", function() self:SyncPartyGroup() end)
    self:On("ROSTER_UPDATED", function() self:SyncPartyGroup() self:PublishQuiet() end)
    self:RegisterEvent("VOICE_CHAT_ERROR", function(_, platformCode, statusCode)
        TG:Print(L["Voice chat error %s (%s)"], self:StatusName(statusCode), tostring(platformCode))
        TG:Fire("VOICE_UPDATED")
    end)
    self:On("STORE_CHANGED", function(ns, key, value) self:OnStoreChanged(ns, key, value) end)
    self:Ticker(TICK, function() self:Apply(false) end)
    self:Ticker(10, function() self:SyncPartyGroup() end)
    if self.cdb.autoJoin then
        TG.After(20, function() if self.enabled and self:Available() and not self:IsJoined() then self:Join() end end)
    end
    self:SetupHud()
end

function Voice:OnDisable()
    self:Restore()
    self:HideHud()
    self:ApplyToasts()
end

function Voice:StatusName(code)
    if Enum.VoiceChatStatusCode then
        for name, value in pairs(Enum.VoiceChatStatusCode) do
            if value == code then return name end
        end
    end
    return tostring(code)
end

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
        if C_VoiceChat.GetActiveVoiceProviderID and Enum.VoiceProviderID then
            local provider = C_VoiceChat.GetActiveVoiceProviderID()
            local name = tostring(provider)
            for key, value in pairs(Enum.VoiceProviderID) do
                if value == provider then name = key end
            end
            lines[#lines + 1] = ("  active provider: %s"):format(name)
        end
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
    lines[#lines + 1] = ("  guild channel: %s"):format(channel and ("%s (%d members)"):format(tostring(channel.name), #(channel.members or {})) or "none")
    channel = self:ActiveChannel()
    lines[#lines + 1] = ("  active channel: %s"):format(channel and ("%s type %s (%d members)"):format(tostring(channel.name), tostring(channel.channelType), #(channel.members or {})) or "none")
    if channel then
        local active = C_VoiceChat.GetActiveChannelID and C_VoiceChat.GetActiveChannelID()
        lines[#lines + 1] = ("  channel id %s, active channel %s, isActive %s, transmitting %s"):format(tostring(channel.channelID), tostring(active), tostring(channel.isActive), tostring(channel.isTransmitting))
        local member = self:LocalMember()
        lines[#lines + 1] = ("  me: member %s, speaking %s, energy %s, muted %s, deafened %s"):format(tostring(member and member.memberID), tostring(member and (speaking[member.memberID] or member.isSpeaking)), tostring(member and (energy[member.memberID] or member.energy)), tostring(self:IsMuted()), tostring(self:IsDeafened()))
        lines[#lines + 1] = ("  mode %s, push to talk held %s, speaking now %s"):format(tostring(C_VoiceChat.GetCommunicationMode and C_VoiceChat.GetCommunicationMode()), tostring(self:PushToTalkHeld()), tostring(self:IsSpeaking()))
    end
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
    elseif cmd == "mute" then Voice:ToggleMute()
    elseif cmd == "debug" then
        Voice.debug = not Voice.debug
        TG:Print(Voice.debug and L["Voice trace on, events are printed to the chat."] or L["Voice trace off."])
    elseif cmd == "hud" then
        if arg == "reset" then
            Voice:ResetHud()
        else
            Voice.db.hud = not Voice.db.hud
        end
        Voice:RefreshHud()
    else
        TG.Window:ShowTab("voice")
    end
end, L["voice: status, join, leave, mute, group <name>, leavegroup, hud, hud reset, debug"])
