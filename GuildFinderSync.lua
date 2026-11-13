local ADDON, GF = ...
local S = {}
GF.Sync = S
local Data = GF.Data
local PREFIX, PROTO = GF.PREFIX, GF.PROTO
local lower = string.lower

S.queue, S.peers, S.buckets, S.chunks = {}, {}, {}, {}
S.stats = { sent = 0, recv = 0, rejected = 0 }
S.chanFails = 0
local SendFn

local RESULT = { [0] = "Success", [1] = "InvalidPrefix", [2] = "InvalidMessage", [3] = "AddonMessageThrottle",
  [4] = "InvalidChatType", [5] = "NotInGroup", [6] = "TargetRequired", [7] = "InvalidChannel",
  [8] = "ChannelThrottle", [9] = "GeneralError", [10] = "ChatThrottle", [11] = "AddOnMessageLockdown", [12] = "TargetOffline" }

---------------------------------------------------------------- Wire helpers
local function Esc(s) s = tostring(s == nil and "" or s); s = s:gsub("%%", "%%25"):gsub("~", "%%7E"); return s end
local function Unesc(s) s = s:gsub("%%7E", "~"):gsub("%%25", "%%"); return s end
local function Split(s, sep, maxn)
  local out, pos = {}, 1
  while true do
    if maxn and #out >= maxn - 1 then out[#out + 1] = s:sub(pos) break end
    local a = s:find(sep, pos, true)
    if not a then out[#out + 1] = s:sub(pos) break end
    out[#out + 1] = s:sub(pos, a - 1)
    pos = a + 1
  end
  return out
end

function S.Encode(l)
  local p = { "L", PROTO, l.id, l.kind, l.author, l.arealm, l.ver, l.posted, l.updated, l.expires, l.active and 1 or 0 }
  for _, def in ipairs(Data.Schema[l.kind]) do p[#p + 1] = l[def.k] end
  for i = 1, #p do p[i] = Esc(p[i]) end
  return table.concat(p, "~")
end

function S.Decode(text, mode)
  local parts = Split(text, "~", 60)
  if parts[1] ~= "L" then return nil, "not a listing" end
  local proto = tonumber(Unesc(parts[2] or ""))
  if not proto or proto < PROTO then return nil, "old protocol (that user needs to update Guild Finder)" end
  local kind = Unesc(parts[4] or "")
  local schema = Data.Schema[kind]
  if not schema or #parts < 11 + #schema then return nil, "short message" end
  local raw = { id = Unesc(parts[3]), kind = kind, author = Unesc(parts[5]), arealm = Unesc(parts[6]),
    ver = Unesc(parts[7]), posted = Unesc(parts[8]), updated = Unesc(parts[9]), expires = Unesc(parts[10]),
    active = Unesc(parts[11]) }
  for i, def in ipairs(schema) do raw[def.k] = Unesc(parts[11 + i]) end
  return Data.Validate(raw, mode or "net")
end

---------------------------------------------------------------- The sync channel (the ONLY transport)
function S.ChannelName() return "GFSync" .. (GF.myFaction or "") end

function S.ChannelId()
  if not GetChannelName then return nil end
  local id = GetChannelName(S.ChannelName())
  if type(id) == "number" and id > 0 then return id end
  return nil
end

function S.Channels() -- kept for the UI tooltip
  local id = S.ChannelId()
  if id then return { { "CHANNEL", id } } end
  return {}
end

function S.HideChannel()
  local name = S.ChannelName()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local cf = _G["ChatFrame" .. i]
    if cf and ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, cf, name) end
  end
end

function S.JoinChannel(force)
  if not (GF.db and GF.db.settings.syncEnabled) then return end
  local now = GetTime()
  if not force and S.lastJoin and now - S.lastJoin < 20 then return end
  S.lastJoin = now
  if S.ChannelId() then S.HideChannel() return end
  local name = S.ChannelName()
  local ok = false
  if JoinTemporaryChannel then ok = pcall(JoinTemporaryChannel, name) end
  if not ok and JoinChannelByName then pcall(JoinChannelByName, name) end
  S.joinTries = 0
  local function check()
    S.joinTries = S.joinTries + 1
    if S.ChannelId() then
      S.HideChannel()
      GF.Debug("sync channel joined:", name, S.ChannelId())
    elseif S.joinTries < 6 then
      C_Timer.After(2, check)
    else
      GF.Debug("could not join sync channel:", name)
    end
  end
  C_Timer.After(2, check)
end

---------------------------------------------------------------- Outgoing queue
function S.Enqueue(text)
  if #S.queue >= 200 then table.remove(S.queue, 1) end
  S.queue[#S.queue + 1] = { text = text, tries = 0 }
end

function S.Send(text)
  if #text <= 230 then return S.Enqueue(text) end
  local n = math.ceil(#text / 200)
  if n > 12 then return end
  S.msgCounter = ((S.msgCounter or 0) + 1) % 4096
  local mid = string.format("%x%02x", S.msgCounter, math.random(0, 255))
  for i = 1, n do
    S.Enqueue(("C~%s~%d~%d~%s"):format(mid, i, n, text:sub((i - 1) * 200 + 1, i * 200)))
  end
end

local function Pump()
  local q = S.queue
  if #q == 0 or not GF.db or not GF.db.settings.syncEnabled or not SendFn then return end
  if S.nextSend and GetTime() < S.nextSend then return end
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
  local id = S.ChannelId()
  if not id then S.nextSend = GetTime() + 5; S.JoinChannel() return end
  local it = q[1]
  local ok, res = pcall(SendFn, PREFIX, it.text, "CHANNEL", id)
  local code = 0
  if not ok then code, S.stats.lastError, S.stats.lastErrorT = 9, tostring(res), GetTime()
  elseif type(res) == "number" then code = res
  elseif res == false then code = 9 end
  if code == 0 then
    table.remove(q, 1)
    S.chanFails = 0
    S.stats.sent, S.stats.lastSend, S.stats.lastError = S.stats.sent + 1, GetTime(), nil
  elseif code == 3 or code == 8 or code == 10 or code == 11 then -- throttled / lockdown: retry later
    it.tries = it.tries + 1
    if it.tries > 5 then table.remove(q, 1) end
    S.nextSend = GetTime() + (code == 11 and 5 or 2)
  elseif code == 7 then -- InvalidChannel: the client refuses addon messages on this channel
    S.chanFails = S.chanFails + 1
    S.stats.lastError = "The game rejected addon messages on the sync channel (InvalidChannel). Syncing is unavailable on this client build."
    S.stats.lastErrorT = GetTime()
    for i = #q, 1, -1 do q[i] = nil end
    S.nextSend = GetTime() + math.min(60 * S.chanFails, 600)
    GF.Debug("InvalidChannel from SendAddonMessage; backing off", S.chanFails)
  else
    table.remove(q, 1)
    S.stats.lastError = "SendAddonMessage result " .. tostring(RESULT[code] or code)
    S.stats.lastErrorT = GetTime()
    GF.Debug("send failed", RESULT[code] or code)
  end
end

function S.Broadcast(text)
  if not GF.db.settings.syncEnabled then return end
  S.Send(text)
end
function S.Publish(l) S.Broadcast(S.Encode(l)) end
function S.PublishDelete(l) S.Broadcast(("X~%d~%s~%d"):format(PROTO, l.id, l.ver + 1)) end

function S.Request(manual)
  if not GF.db.settings.syncEnabled then return false, "Sync is disabled in settings." end
  local now = GetTime()
  if manual and S.lastReq and now - S.lastReq < 15 then return false, "Please wait a few seconds between refreshes." end
  S.lastReq = now
  if not S.ChannelId() then S.JoinChannel(true) end
  local since = manual and 0 or math.max(0, (GF.db.lastUpdate or 0) - 3600)
  S.Broadcast(("Q~%d~%d"):format(PROTO, since))
  return true
end

---------------------------------------------------------------- Incoming
local function SenderIsAuthor(sender, l)
  local s = lower(sender)
  return s == lower(l.author) or s == lower(l.author .. "-" .. Data.Norm(l.arealm))
end

-- Answers a request on the channel. Own listings always; a few cached ones sometimes (keeps channel traffic low).
-- Listings read from chat are unverified and never passed on.
local function Respond(since)
  local now = GetTime()
  if S.lastRespond and now - S.lastRespond < 30 then return end
  S.lastRespond = now
  local mine, other, ts = {}, {}, time()
  for _, l in pairs(GF.db.listings) do
    if l.updated > since and l.expires > ts and not Data.IsBlocked(l) and not Data.IsChat(l) then
      if Data.IsMine(l) then mine[#mine + 1] = l else other[#other + 1] = l end
    end
  end
  for _, l in ipairs(mine) do S.Send(S.Encode(l)) end
  if math.random() < 0.25 then
    table.sort(other, function(a, b) return a.updated > b.updated end)
    for i = 1, math.min(8, #other) do S.Send(S.Encode(other[i])) end
  end
end

local function Dispatch(text, sender)
  local typ = text:sub(1, 2)
  if typ == "L~" then
    local l, err = S.Decode(text, "net")
    if not l then S.stats.rejected = S.stats.rejected + 1; GF.Debug("reject listing:", err, sender); return end
    local relayed = not SenderIsAuthor(sender, l)
    if relayed and not GF.db.settings.acceptRelayed then return end
    local res, why = Data.Merge(l, relayed)
    if res then
      S.stats.recv, S.stats.lastRecv = S.stats.recv + 1, GetTime()
      if GF.UI and GF.UI.RequestRefresh then GF.UI.RequestRefresh() end
    else GF.Debug("not merged:", why, l.id) end
  elseif typ == "X~" then
    local parts = Split(text, "~", 6)
    local id = parts[3] or ""
    local ex = GF.db.listings[id]
    if ex and not Data.IsMine(ex) and SenderIsAuthor(sender, ex) then
      Data.RemoveRemote(id)
      if GF.UI and GF.UI.RequestRefresh then GF.UI.RequestRefresh() end
    end
  elseif typ == "Q~" then
    local parts = Split(text, "~", 5)
    local proto, since = tonumber(parts[2]), tonumber(parts[3]) or 0
    if not proto or proto < PROTO then return end
    C_Timer.After(1 + math.random() * 4, function() Respond(since) end)
  end
end

function S.OnMessage(prefix, text, channel, sender)
  if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
  if #text > 255 or #text < 3 then return end
  if not GF.db or not GF.db.settings.syncEnabled then return end
  if channel ~= "CHANNEL" then GF.Debug("ignored message from", tostring(channel)) return end -- channel-only
  sender = Ambiguate and Ambiguate(sender, "none") or sender
  if lower(sender) == lower(GF.me or "") then return end
  local now = GetTime()
  local b = S.buckets[sender]
  if not b or now - b.t > 60 then
    if not b and S.bucketCount and S.bucketCount > 300 then S.buckets, S.bucketCount = {}, 0 end
    b = { t = now, n = 0 }
    S.buckets[sender] = b
    S.bucketCount = (S.bucketCount or 0) + 1
  end
  b.n = b.n + 1
  if b.n > 60 then S.stats.rejected = S.stats.rejected + 1; return end
  local pc = 0
  for _ in pairs(S.peers) do pc = pc + 1 end
  if pc < 200 or S.peers[sender] then S.peers[sender] = { t = now } end

  if text:sub(1, 2) == "C~" then
    local mid, i, n, part = text:match("^C~(%x+)~(%d+)~(%d+)~(.*)$")
    i, n = tonumber(i), tonumber(n)
    if not mid or #mid > 8 or not i or not n or n < 2 or n > 12 or i < 1 or i > n then return end
    local key = sender .. "#" .. mid
    local buf = S.chunks[key]
    if not buf then
      local open, total = 0, 0
      for _, v in pairs(S.chunks) do total = total + 1; if v.sender == sender then open = open + 1 end end
      if open >= 3 or total >= 40 then return end
      buf = { n = n, parts = {}, got = 0, t = now, sender = sender }
      S.chunks[key] = buf
    end
    if buf.n ~= n then return end
    if not buf.parts[i] then buf.parts[i] = part; buf.got = buf.got + 1 end
    if buf.got == n then
      S.chunks[key] = nil
      local full = table.concat(buf.parts)
      if #full <= 2400 and full:sub(1, 2) ~= "C~" then Dispatch(full, sender) end
    end
  else
    Dispatch(text, sender)
  end
end

---------------------------------------------------------------- Status & diagnostics
function S.Status()
  local s = GF.db.settings
  if not s.syncEnabled then return "off", "Sync is turned off", 0 end
  local now, peers = GetTime(), 0
  for _, p in pairs(S.peers) do if now - p.t < 1800 then peers = peers + 1 end end
  if S.chanFails > 0 and S.stats.lastErrorT and now - S.stats.lastErrorT < 900 then
    return "error", S.stats.lastError, peers
  end
  if not S.ChannelId() then return "idle", "Joining the sync channel...", peers end
  if peers > 0 then
    return "ok", (peers == 1 and "1 other user online" or (peers .. " other users online")), peers
  end
  return "idle", "Connected, no other users seen yet", peers
end

function S.Diag()
  local out = {}
  local id = S.ChannelId()
  out[#out + 1] = ("Channel: %s  id=%s"):format(S.ChannelName(), tostring(id))
  local restricted = C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
    and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()
  out[#out + 1] = "AreOutgoingAddonChatMessagesRestricted: " .. tostring(restricted)
  local lock = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
  out[#out + 1] = "InChatMessagingLockdown: " .. tostring(lock)
  if id and SendFn then
    local ok, res = pcall(SendFn, PREFIX, "T~1", "CHANNEL", id)
    out[#out + 1] = "Test send: " .. (ok and (res == nil and "nil (no result returned)" or tostring(RESULT[res] or res)) or ("error: " .. tostring(res)))
  else
    out[#out + 1] = "Test send: skipped (not joined to the channel)"
  end
  out[#out + 1] = ("Queue: %d  Sent: %d  Received: %d  Rejected: %d"):format(#S.queue, S.stats.sent, S.stats.recv, S.stats.rejected)
  return out
end

---------------------------------------------------------------- Init
function S.Init()
  SendFn = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  local reg = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
  if reg then pcall(reg, PREFIX) end

  -- Hide the channel's join/notice lines from chat.
  if ChatFrame_AddMessageEventFilter then
    local function filter(_, _, _, _, _, chanString, _, _, _, _, chanName)
      local ok, hide = pcall(function()
        return (type(chanName) == "string" and lower(chanName):find("gfsync", 1, true) ~= nil)
          or (type(chanString) == "string" and lower(chanString):find("gfsync", 1, true) ~= nil)
      end)
      return ok and hide or false
    end
    pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL_NOTICE", filter)
    pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL_NOTICE_USER", filter)
    pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL", filter)
  end

  local f = CreateFrame("Frame")
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:SetScript("OnEvent", function(_, _, ...)
    local ok, err = pcall(S.OnMessage, ...)
    if not ok then GF.Debug("OnMessage error:", err) end
  end)
  C_Timer.NewTicker(0.7, function() local ok, e = pcall(Pump); if not ok then GF.Debug("Pump error:", e) end end)
  C_Timer.NewTicker(30, function()
    local now = GetTime()
    for k, v in pairs(S.chunks) do if now - v.t > 30 then S.chunks[k] = nil end end
    for k, v in pairs(S.peers) do if now - v.t > 3600 then S.peers[k] = nil end end
  end)
  C_Timer.NewTicker(60, function() -- keep the sync channel joined
    if GF.db.settings.syncEnabled and not S.ChannelId() then S.JoinChannel() end
  end)
  C_Timer.NewTicker(300, function() Data.Cleanup(); if GF.UI and GF.UI.RequestRefresh then GF.UI.RequestRefresh() end end)
  C_Timer.NewTicker(900, function() -- periodic re-announce of own active adverts
    for _, kind in ipairs({ "G", "P" }) do
      local l = Data.MyAd(kind)
      if l then S.Publish(l) end
    end
  end)
end
