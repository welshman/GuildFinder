local ADDON, GF = ...
GF.NAME, GF.VERSION, GF.PROTO, GF.DB_VERSION = "Guild Finder", "1.4.0", 2, 3
GF.PREFIX = "GUILDFINDER_SYNC"
GF.L = setmetatable({}, { __index = function(_, k) return k end }) -- localization hook
GF.debugLog = {}

local Data = {}
GF.Data = Data
local floor, lower = math.floor, string.lower

function GF.Debug(...)
  local p = {}
  for i = 1, select("#", ...) do p[i] = tostring((select(i, ...))) end
  local msg = table.concat(p, " ")
  GF.debugLog[#GF.debugLog + 1] = date("%H:%M:%S ") .. msg
  if #GF.debugLog > 80 then table.remove(GF.debugLog, 1) end
  if GF.db and GF.db.debug then print("|cff33ff99GuildFinder|r |cff888888[debug]|r " .. msg) end
end
function GF.Print(msg) print("|cff33ff99Guild Finder|r: " .. tostring(msg)) end

---------------------------------------------------------------- Enums / schema
-- WoW Forever: level cap 60, realmless (ruleset instead), raids Barrow Deeps (10) / Hyjal Summit (20) / Onyxia's Lair (40).
local E = {
  factions   = { "Any", "Alliance", "Horde" },
  rulesets   = { "Normal", "PvP", "Roleplaying", "Roleplay-PvP", "Hardcore" },
  guildTypes = { "Casual", "Social", "Leveling", "Raiding", "PvP", "RP", "Trading", "New Player Friendly", "Other" },
  foci       = { "Raiding", "PvP", "Leveling", "Social", "RP", "Professions", "Other" },
  roles      = { "Any", "Tank", "Healer", "Melee DPS", "Ranged DPS" },
  exp        = { "New player", "Returning player", "Casual", "Experienced", "Hardcore", "Other" },
  goals      = { "Any", "Casual/Social", "Leveling", "Raiding", "PvP", "RP" },
  sizes      = { "Any", "Small", "Medium", "Large" },
  raids      = { "Any", "Barrow Deeps (10)", "Hyjal Summit (20)", "Onyxia's Lair (40)", "Multiple raids" },
  stages     = { "Any", "Levelling", "Level 60" },
}
GF.Enums = E

-- Field order here IS the wire order. Only ever APPEND new fields (and bump GF.PROTO if the format changes).
-- "hidden" fields are filled in automatically and never shown in the editor.
Data.Schema = {
  G = {
    { k = "name",     t = "s", max = 32,  req = true, label = "Guild name",   tip = "Exact in-game guild name." },
    { k = "faction",  t = "e", enum = "factions", hidden = true, label = "Faction", tip = "Set automatically from your character." },
    { k = "ruleset",  t = "e", enum = "rulesets", hidden = true, label = "Ruleset", tip = "Set automatically from the game." },
    { k = "contact",  t = "s", max = 24,  req = true, label = "Contact character", tip = "Character applicants will whisper. Pick someone who is online often." },
    { k = "gtype",    t = "e", enum = "guildTypes",   label = "Guild type",   tip = "The overall style of the guild." },
    { k = "focus",    t = "e", enum = "foci",         label = "Primary focus", tip = "What the guild mostly does together." },
    { k = "raid",     t = "e", enum = "raids",        label = "Raid target",  tip = "The raid you are recruiting for. 'Any' if you are not raid focused." },
    { k = "stage",    t = "e", enum = "stages",       label = "Recruiting for", tip = "Levelling characters, level 60 characters, or any." },
    { k = "days",     t = "s", max = 30,  label = "Active / raid days",       tip = "e.g. Tue, Thu, Sun or Weekends." },
    { k = "times",    t = "s", max = 20,  label = "Times",                    tip = "e.g. 20:00-23:00" },
    { k = "tz",       t = "s", max = 12,  label = "Timezone",                 tip = "e.g. GMT, CET, EST." },
    { k = "progress", t = "s", max = 30,  label = "Raid progress",            tip = "e.g. Onyxia cleared. Leave empty if not applicable." },
    { k = "size",     t = "s", max = 30,  label = "Size / target",            tip = "e.g. small friendly guild, large raiding guild." },
    { k = "minLevel", t = "n", min = 0, max = 60,   label = "Min level",      tip = "Minimum character level, 0-60 (0 = none)." },
    { k = "spotsT",   t = "n", min = 0, max = 40,   label = "Tank spots open", tip = "How many tanks you want. 0 = none needed." },
    { k = "spotsH",   t = "n", min = 0, max = 40,   label = "Healer spots open", tip = "How many healers you want. 0 = none needed." },
    { k = "spotsD",   t = "n", min = 0, max = 40,   label = "DPS spots open", tip = "How many damage dealers you want. 0 = none needed." },
    { k = "bnet",     t = "s", max = 40,  label = "Battle.net note (optional)", tip = "Optional extra contact note. Whisper is always the default." },
    { k = "needs",    t = "s", max = 60,  wide = true, label = "Class notes (wanted classes, anything else)", tip = "e.g. priests and warlocks especially welcome." },
    { k = "desc",     t = "s", max = 250, wide = true, label = "Description (max 250)", tip = "Short pitch. No links or advertising." },
  },
  P = {
    { k = "name",     t = "s", max = 24,  req = true, label = "Character name", tip = "Your character." },
    { k = "faction",  t = "e", enum = "factions", hidden = true, label = "Faction", tip = "Set automatically from your character." },
    { k = "ruleset",  t = "e", enum = "rulesets", hidden = true, label = "Ruleset", tip = "Set automatically from the game." },
    { k = "class",    t = "s", max = 16,  label = "Class",                    tip = "e.g. Priest." },
    { k = "spec",     t = "s", max = 20,  label = "Talent spec",              tip = "e.g. Holy, Fury, Combat." },
    { k = "role",     t = "e", enum = "roles",        label = "Role",         tip = "Tank, Healer, Melee DPS, Ranged DPS or Any." },
    { k = "level",    t = "n", min = 1, max = 60,   label = "Level",          tip = "Current level (1-60)." },
    { k = "stage",    t = "e", enum = "stages",       label = "Levelling or level 60", tip = "Are you still levelling, or at the level cap?" },
    { k = "exp",      t = "e", enum = "exp",          label = "Experience",   tip = "How experienced you are." },
    { k = "goal",     t = "e", enum = "goals",        label = "Looking for",  tip = "The kind of guild you want." },
    { k = "raid",     t = "e", enum = "raids",        label = "Raid interest", tip = "The raid you want to do, or 'Any'." },
    { k = "days",     t = "s", max = 30,  label = "Days available",           tip = "e.g. Mon-Fri evenings, Weekends." },
    { k = "times",    t = "s", max = 20,  label = "Times",                    tip = "e.g. 19:00-23:00" },
    { k = "tz",       t = "s", max = 12,  label = "Timezone",                 tip = "e.g. GMT." },
    { k = "gsize",    t = "e", enum = "sizes",        label = "Guild size",   tip = "Preferred guild size." },
    { k = "bnet",     t = "s", max = 40,  label = "Battle.net note (optional)", tip = "Optional. Whisper is always the default." },
    { k = "about",    t = "s", max = 250, wide = true, label = "About me (max 250)", tip = "Short intro. No links or advertising." },
  },
}

---------------------------------------------------------------- Settings / DB
GF.DefaultSettings = {
  syncEnabled = true, acceptRelayed = true, expiryDays = 7, maxAdverts = 1, autoRenew = false,
  notify = true, notifySound = false, scanChat = false, expiryWarn = true,
  scale = 1, compact = false, reason = "I like what your guild is about",
  appTemplate = "", inviteTemplate = "", -- filled from GF.Templates
}

function Data.Migrate(db)
  db.dbVersion = db.dbVersion or 0
  db.settings   = type(db.settings) == "table" and db.settings or {}
  db.listings   = type(db.listings) == "table" and db.listings or {}
  db.tombstones = type(db.tombstones) == "table" and db.tombstones or {}
  db.blocked    = type(db.blocked) == "table" and db.blocked or {}
  db.blocked.listings = db.blocked.listings or {}
  db.blocked.authors  = db.blocked.authors or {}
  db.window     = type(db.window) == "table" and db.window or {}
  db.favorites     = type(db.favorites) == "table" and db.favorites or {}
  db.applications  = type(db.applications) == "table" and db.applications or {}
  db.notes         = type(db.notes) == "table" and db.notes or {}
  db.chatIds       = type(db.chatIds) == "table" and db.chatIds or {}
  db.ratings       = db.ratings or {} -- reserved
  for k, v in pairs(GF.DefaultSettings) do if db.settings[k] == nil then db.settings[k] = v end end
  if db.dbVersion < 3 then
    -- v3: ruleset is automatic, structured roster spots, raid targets. Nothing is wiped.
    db.settings.myRuleset, db.settings.onlyRuleset, db.settings.sameFaction, db.settings.sameRealm = nil, nil, nil, nil
  end
  if db.settings.appTemplate == "" then db.settings.appTemplate = GF.Templates.DEFAULT_APP end
  if db.settings.inviteTemplate == "" then db.settings.inviteTemplate = GF.Templates.DEFAULT_INVITE end
  for id, l in pairs(db.listings) do -- drop corrupt entries only
    local clean = Data.Validate(l, "stored")
    if clean then db.listings[id] = clean else db.listings[id] = nil end
  end
  db.dbVersion = GF.DB_VERSION
end

---------------------------------------------------------------- Ruleset (automatic)
-- Forever exposes the ruleset through C_GameRules.IsGameRuleActive. Falls back to Normal.
function Data.GetRuleset()
  local gr = C_GameRules
  local enum = Enum and Enum.GameRule
  local function active(key)
    if not (gr and gr.IsGameRuleActive and enum and enum[key]) then return false end
    local ok, v = pcall(gr.IsGameRuleActive, enum[key])
    return ok and v == true
  end
  local hardcore = active("HardcoreRuleset")
  if not hardcore and gr and gr.IsHardcoreActive then
    local ok, v = pcall(gr.IsHardcoreActive)
    hardcore = ok and v == true
  end
  if hardcore then return "Hardcore" end
  local realm = ""
  if GetRealmName then realm = lower(tostring(GetRealmName() or "")) end
  local rp, pvp = active("RPRuleset"), active("PvPRuleset")
  if (rp and pvp) or realm:find("rp[%s%-]*pvp") then return "Roleplay-PvP" end
  if rp then return "Roleplaying" end
  if pvp then return "PvP" end
  return "Normal"
end

---------------------------------------------------------------- Sanitising
local function CutUtf8(s, n)
  if #s <= n then return s end
  s = s:sub(1, n)
  local i = #s
  while i > 0 do
    local b = s:byte(i)
    if b < 0x80 then break end
    if b >= 0xC0 then
      local need = b >= 0xF0 and 4 or b >= 0xE0 and 3 or 2
      if #s - i + 1 < need then s = s:sub(1, i - 1) end
      break
    end
    i = i - 1
  end
  return s
end
Data.CutUtf8 = CutUtf8

local function Clean(s, max)
  s = tostring(s == nil and "" or s)
  s = s:gsub("|", ""):gsub("%c", " ")
  s = strtrim(s)
  s = s:gsub("%s+", " ")
  return CutUtf8(s, max or 100)
end
Data.Clean = Clean

local function Num(v, lo, hi)
  v = tonumber(v)
  if not v or v ~= v then return nil end
  v = floor(v)
  if v < lo then v = lo elseif v > hi then v = hi end
  return v
end

local function EnumFallback(list)
  for _, o in ipairs(list) do if o == "Other" or o == "Any" then return o end end
  return list[1]
end

function Data.Norm(s) return (lower(s or ""):gsub("[%s%-']", "")) end

local SPAM = { "https?:", "www%.", "%.com", "%.net", "%.org", "%.gg", "buy gold", "cheap gold",
  "gold seller", "powerlevel", "paypal", "%d+%$", "wts " }
Data.BannedWords = { "fuck", "cunt" } -- extend as needed
function Data.IsSpam(text)
  local t = lower(text or "")
  for _, p in ipairs(SPAM) do if t:find(p) then return true end end
  for _, w in ipairs(Data.BannedWords) do if t:find(w, 1, true) then return true end end
  if t:find("(.)%1%1%1%1%1") then return true end
  local up = select(2, text:gsub("%u", ""))
  local al = select(2, text:gsub("%a", ""))
  if al >= 20 and up / al > 0.8 then return true end
  return false
end

-- mode: "local" (user input), "net", "import", "stored"
function Data.Validate(raw, mode)
  if type(raw) ~= "table" then return nil, "not a table" end
  local now = time()
  local kind = raw.kind
  if kind ~= "G" and kind ~= "P" then return nil, "bad kind" end
  local id = tostring(raw.id or "")
  if not id:match("^%x+$") or #id < 8 or #id > 24 then return nil, "bad id" end
  local l = { id = id, kind = kind }
  l.author = Clean(raw.author, 24)
  if #l.author < 2 or l.author:find("[%s%-~]") then return nil, "bad author" end
  l.arealm = (Clean(raw.arealm, 30):gsub("[%s%-']", ""))
  if l.arealm == "" then return nil, "bad realm" end
  l.ver = Num(raw.ver, 1, 999999)
  local hi = (mode == "stored") and 2147483647 or now + 300
  l.posted, l.updated = Num(raw.posted, 0, hi), Num(raw.updated, 0, hi)
  l.expires = Num(raw.expires, 0, 2147483647)
  if not (l.ver and l.posted and l.updated and l.expires) then return nil, "bad numbers" end
  if l.updated < l.posted then l.updated = l.posted end
  if mode ~= "stored" then l.expires = math.min(l.expires, now + 30 * 86400) end
  if (mode == "net" or mode == "import") and l.expires <= now then return nil, "expired" end
  l.active = raw.active == true or raw.active == 1 or raw.active == "1"

  local texts = {}
  for _, def in ipairs(Data.Schema[kind]) do
    local v = raw[def.k]
    if def.t == "s" then
      v = Clean(v, def.max)
      if def.req and v == "" then return nil, def.label .. " is required" end
      if v ~= "" then texts[#texts + 1] = v end
    elseif def.t == "e" then
      local list, ok = E[def.enum], false
      if mode == "local" and def.k == "faction" then v = GF.myFaction or "Any"
      elseif mode == "local" and def.k == "ruleset" then v = Data.GetRuleset() end
      for _, o in ipairs(list) do if o == v then ok = true break end end
      if not ok then
        if mode == "local" or mode == "stored" then v = EnumFallback(list)
        else return nil, "bad value for " .. def.k end
      end
    else
      v = Num(v, def.min or 0, def.max or 9999) or 0
    end
    l[def.k] = v
  end
  if mode ~= "stored" and Data.IsSpam(table.concat(texts, " ")) then
    return nil, "Text looks like spam (links, ads or blocked words are not allowed)"
  end
  return l
end

---------------------------------------------------------------- Ownership & status
function Data.IsMine(l) return l.author == GF.me and Data.Norm(l.arealm) == Data.Norm(GF.myRealm) end
function Data.IsBlocked(l)
  local b = GF.db.blocked
  return b.listings[l.id] or b.authors[lower(l.author)] or false
end
-- Players can only group and guild with their own faction and ruleset, so everything else is never shown.
function Data.WrongFaction(l)
  return GF.myFaction ~= nil and l.faction ~= "Any" and l.faction ~= GF.myFaction
end
function Data.WrongRuleset(l, rs) return l.ruleset ~= (rs or Data.GetRuleset()) end
function Data.Status(l, now)
  now = now or time()
  if not l.active then return "inactive" end
  if l.expires <= now then return "expired" end
  return "active"
end
function Data.Mine(kind)
  local out = {}
  for _, l in pairs(GF.db.listings) do if l.kind == kind and Data.IsMine(l) then out[#out + 1] = l end end
  table.sort(out, function(a, b) return a.updated > b.updated end)
  return out
end
function Data.MyAd(kind)
  for _, l in ipairs(Data.Mine(kind)) do if Data.Status(l) == "active" then return l end end
end
function Data.Count()
  local n = 0
  for _ in pairs(GF.db.listings) do n = n + 1 end
  return n
end

function Data.NewID()
  local h = 0
  for c in tostring(GF.me):gmatch(".") do h = (h * 31 + c:byte()) % 65536 end
  return string.format("%08x%04x%04x", time(), math.random(0, 65535), h)
end

function Data.Defaults(kind)
  local d = { faction = GF.myFaction or "Any", ruleset = Data.GetRuleset(), raid = "Any" }
  if kind == "G" then
    d.contact, d.gtype, d.focus, d.stage = GF.me, "Casual", "Social", "Any"
    if IsInGuild and IsInGuild() then d.name = (GetGuildInfo("player")) or "" end
  else
    d.name, d.class, d.level = GF.me, (UnitClass("player")), UnitLevel("player")
    d.stage = (d.level or 1) >= 60 and "Level 60" or "Levelling"
    d.role, d.exp, d.goal, d.gsize = "Any", "Casual", "Any", "Any"
  end
  return d
end

function Data.CanCreate(kind)
  if #Data.Mine(kind) >= (GF.db.settings.maxAdverts or 1) then
    return false, "Advert limit reached (" .. GF.db.settings.maxAdverts .. " per type per character). Edit or delete an existing one."
  end
  return true
end

---------------------------------------------------------------- Mutations (own listings only)
local function Publish(l) if GF.Sync and GF.Sync.Publish then GF.Sync.Publish(l) end end

function Data.Save(kind, vals, id)
  local db, now = GF.db, time()
  local old = id and db.listings[id]
  if id and (not old or not Data.IsMine(old)) then return nil, "You can only edit your own adverts." end
  if not old then
    local ok, err = Data.CanCreate(kind)
    if not ok then return nil, err end
  end
  local raw = {}
  for k, v in pairs(vals) do raw[k] = v end
  raw.kind, raw.author, raw.arealm = kind, GF.me, GF.myRealm
  raw.faction, raw.ruleset = GF.myFaction or "Any", Data.GetRuleset()
  raw.id = old and old.id or Data.NewID()
  raw.ver = (old and old.ver or 0) + 1
  raw.posted, raw.updated = old and old.posted or now, now
  raw.expires = now + (db.settings.expiryDays or 7) * 86400
  raw.active = old and old.active or (old == nil)
  local l, err = Data.Validate(raw, "local")
  if not l then return nil, err end
  db.listings[l.id] = l
  db.lastUpdate = now
  Publish(l)
  return l
end

local function Bump(id, fn)
  local l = GF.db.listings[id]
  if not l or not Data.IsMine(l) then return nil, "Not your advert." end
  fn(l)
  l.ver, l.updated = l.ver + 1, time()
  GF.db.lastUpdate = l.updated
  Publish(l)
  return l
end
function Data.Renew(id)
  return Bump(id, function(l) l.expires = time() + GF.db.settings.expiryDays * 86400; l.active = true end)
end
function Data.SetActive(id, on) return Bump(id, function(l) l.active = on and true or false end) end

function Data.Delete(id)
  local l = GF.db.listings[id]
  if not l or not Data.IsMine(l) then return nil, "Not your advert." end
  GF.db.listings[id] = nil
  GF.db.tombstones[id] = time()
  if GF.Sync then GF.Sync.PublishDelete(l) end
  return true
end

-- Own adverts that run out within `hours` (or already have), for the reminder.
function Data.ExpiringSoon(hours)
  local out, now = {}, time()
  for _, kind in ipairs({ "G", "P" }) do
    for _, l in ipairs(Data.Mine(kind)) do
      if l.active and l.expires - now < hours * 3600 then out[#out + 1] = l end
    end
  end
  return out
end

---------------------------------------------------------------- Favourites, contacted, notes (local only, never shared)
function Data.IsFav(id) return GF.db.favorites[id] and true or false end
function Data.ToggleFav(id)
  if GF.db.favorites[id] then GF.db.favorites[id] = nil else GF.db.favorites[id] = true end
end
function Data.GetContacted(id) return GF.db.applications[id] end
function Data.MarkContacted(l)
  GF.db.applications[l.id] = { t = time(), name = l.name, kind = l.kind, who = l.kind == "G" and l.contact or l.author }
end
function Data.ListFrom(tbl)
  local out, rs = {}, Data.GetRuleset()
  for id, v in pairs(tbl) do
    local l = GF.db.listings[id]
    if l and not Data.IsBlocked(l) and not Data.WrongFaction(l) and not Data.WrongRuleset(l, rs) then
      out[#out + 1] = l
    end
  end
  table.sort(out, function(a, b)
    local ta = type(tbl[a.id]) == "table" and tbl[a.id].t or a.updated
    local tb = type(tbl[b.id]) == "table" and tbl[b.id].t or b.updated
    if ta ~= tb then return ta > tb end
    return a.id < b.id
  end)
  return out
end

---------------------------------------------------------------- Chat-scanned listings (opt-in, unverified, never synced)
function Data.IsChat(l) return GF.db.chatIds[l.id] and true or false end

function Data.AddChatListing(text, sender)
  local db = GF.db
  if not db.settings.scanChat then return end
  if type(text) ~= "string" or type(sender) ~= "string" then return end
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  if #text < 15 or #text > 255 then return end
  local t = lower(text)
  local recruit = t:find("recruit", 1, true) or t:find("join us", 1, true) or t:find("new members", 1, true)
  local guildy = t:find("guild", 1, true) or text:find("<[^>]+>")
  if not (recruit and guildy) then return end
  if Data.IsSpam(text) then return end
  sender = Ambiguate and Ambiguate(sender, "none") or sender
  sender = sender:gsub("%-.*$", "")
  if sender == "" or sender == GF.me then return end
  if db.blocked.authors[lower(sender)] then return end
  local h = 5381
  for i = 1, #sender do h = (h * 33 + sender:byte(i)) % 4294967296 end
  local id = string.format("%08x%04x", h, 0xC4A7)
  if db.blocked.listings[id] then return end
  local now = time()
  local old = db.listings[id]
  if old and not db.chatIds[id] then return end -- never overwrite a real (synced) listing
  local gname = text:match("<([^>]+)>") or (sender .. "'s guild")
  local l = Data.Validate({
    kind = "G", id = id, author = sender, arealm = GF.myRealm or "Forever",
    ver = (old and old.ver or 0) + 1, posted = old and old.posted or now, updated = now, expires = now + 86400,
    active = true, name = gname, contact = sender, gtype = "Other", focus = "Other", desc = text,
  }, "local")
  if not l then return end
  if not old then
    local count, oldest = 0, nil
    for cid in pairs(db.chatIds) do
      local c = db.listings[cid]
      if c then
        count = count + 1
        if not oldest or c.updated < oldest.updated then oldest = c end
      else db.chatIds[cid] = nil end
    end
    if count >= 80 and oldest then db.listings[oldest.id] = nil; db.chatIds[oldest.id] = nil end
  end
  db.listings[id] = l
  db.chatIds[id] = true
  db.lastUpdate = now
  if not old then Data.Notify(l) end
  if GF.UI and GF.UI.RequestRefresh then GF.UI.RequestRefresh() end
end

---------------------------------------------------------------- Merge (network / import)
function Data.Merge(l, relayed, allowOwn)
  local db = GF.db
  if Data.WrongFaction(l) then return nil, "other faction" end
  if Data.WrongRuleset(l) then return nil, "other ruleset" end
  if db.tombstones[l.id] then return nil, "deleted" end
  if Data.IsBlocked(l) then return nil, "blocked" end
  local ex = db.listings[l.id]
  if Data.IsMine(l) and not allowOwn then return nil, "own listing (never overwritten by network)" end
  if ex then
    if ex.author ~= l.author or ex.kind ~= l.kind then return nil, "id hijack" end
    if l.ver <= ex.ver then return nil, "not newer" end
  else
    local cnt, total, oldest = 0, 0, nil
    for _, o in pairs(db.listings) do
      if not Data.IsMine(o) and not db.chatIds[o.id] then
        total = total + 1
        if o.author == l.author and o.kind == l.kind then cnt = cnt + 1 end
        if not oldest or o.updated < oldest.updated then oldest = o end
      end
    end
    if cnt >= 2 then return nil, "author cap" end
    if total >= 500 and oldest then db.listings[oldest.id] = nil end
  end
  db.chatIds[l.id] = nil
  db.listings[l.id] = l
  db.lastUpdate = time()
  if not ex then Data.Notify(l) end
  return ex and "updated" or "new"
end

function Data.RemoveRemote(id)
  GF.db.listings[id] = nil
  GF.db.tombstones[id] = time()
end

function Data.Cleanup()
  local now, db, rs = time(), GF.db, Data.GetRuleset()
  for id, l in pairs(db.listings) do
    if not Data.IsMine(l) and (l.expires <= now or l.updated < now - 60 * 86400
        or Data.WrongFaction(l) or Data.WrongRuleset(l, rs)) then
      db.listings[id] = nil
    end
  end
  for id, t in pairs(db.tombstones) do if t < now - 30 * 86400 then db.tombstones[id] = nil end end
  for id in pairs(db.chatIds) do if not db.listings[id] then db.chatIds[id] = nil end end
  for id in pairs(db.favorites) do if not db.listings[id] then db.favorites[id] = nil end end
  for id in pairs(db.notes) do if not db.listings[id] then db.notes[id] = nil end end
  for id, a in pairs(db.applications) do
    if type(a) ~= "table" or a.t < now - 60 * 86400 then db.applications[id] = nil end
  end
end

function Data.ClearCache()
  for id, l in pairs(GF.db.listings) do if not Data.IsMine(l) then GF.db.listings[id] = nil end end
  GF.db.chatIds = {}
end

function Data.Block(l, authorToo)
  GF.db.blocked.listings[l.id] = true
  if authorToo then GF.db.blocked.authors[lower(l.author)] = true end
end

---------------------------------------------------------------- Matching
local DAYS = { "mon", "tue", "wed", "thu", "fri", "sat", "sun" }
local function DaySet(s)
  s = lower(s or "")
  local set = {}
  if s:find("%f[%a]any%f[%A]") or s:find("daily") or s:find("every") or s:find("flex") then
    for _, d in ipairs(DAYS) do set[d] = true end
    return set
  end
  for _, d in ipairs(DAYS) do if s:find(d, 1, true) then set[d] = true end end
  if s:find("weekend") then set.sat, set.sun = true, true end
  if s:find("weekday") then for i = 1, 5 do set[DAYS[i]] = true end end
  return set
end
function Data.Overlap(a, b)
  local sa, sb, n = DaySet(a), DaySet(b), 0
  for d in pairs(sa) do if sb[d] then n = n + 1 end end
  return n
end

local GOALMAP = {
  ["Casual/Social"] = { "Casual", "Social", "New Player Friendly" }, Leveling = { "Leveling" },
  Raiding = { "Raiding" }, PvP = { "PvP" }, RP = { "RP" },
}
local function GoalCompat(g, p)
  if p.goal == "Any" then return true end
  for _, t in ipairs(GOALMAP[p.goal] or {}) do if g.gtype == t or g.focus == t then return true end end
  return false
end

local ROLETEXT = { Tank = { "tank" }, Healer = { "heal" }, DPS = { "dps", "melee", "ranged", "damage", "caster" } }
local function RoleGroup(role)
  if role == "Tank" or role == "Healer" then return role end
  if role == "Melee DPS" or role == "Ranged DPS" or role == "DPS" then return "DPS" end
  return nil
end
-- Does this guild advert want the given role ("Tank", "Healer" or "DPS")?
local function GuildWantsRole(g, group)
  local t, h, d = g.spotsT or 0, g.spotsH or 0, g.spotsD or 0
  if t + h + d > 0 then
    if group == "Tank" then return t > 0 elseif group == "Healer" then return h > 0 else return d > 0 end
  end
  local needs = lower(g.needs or "")
  if needs == "" then return true end
  for _, k in ipairs(ROLETEXT[group] or {}) do if needs:find(k, 1, true) then return true end end
  return false
end
local function RoleCompat(g, p)
  local group = RoleGroup(p.role)
  if not group then return true end
  if GuildWantsRole(g, group) then return true end
  return p.class ~= "" and lower(g.needs or ""):find(lower(p.class), 1, true) ~= nil
end

function Data.MatchesMe(l)
  local mine = Data.MyAd(l.kind == "G" and "P" or "G")
  if not mine then return false end
  local g, p = l.kind == "G" and l or mine, l.kind == "P" and l or mine
  if g.faction ~= "Any" and p.faction ~= "Any" and g.faction ~= p.faction then return false end
  if g.ruleset ~= p.ruleset then return false end
  return GoalCompat(g, p) and RoleCompat(g, p)
end

-- Matching listings are batched into one chat line (and one minimap pulse) instead of one line each.
local pend = { G = 0, P = 0, timer = false }
local function FlushNotify()
  pend.timer = false
  local g, p = pend.G, pend.P
  pend.G, pend.P = 0, 0
  if g + p == 0 then return end
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. (g == 1 and " guild" or " guilds") end
  if p > 0 then parts[#parts + 1] = p .. (p == 1 and " player" or " players") end
  GF.Print(("%d new matching listing%s (%s). Type /gfinder to view."):format(g + p, (g + p) == 1 and "" or "s", table.concat(parts, ", ")))
  local s = GF.db.settings
  if s.notifySound and PlaySound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then PlaySound(SOUNDKIT.TELL_MESSAGE) end
  if GF.Alert then GF.Alert() end
end
function Data.Notify(l)
  local s = GF.db.settings
  if not s.notify or Data.IsMine(l) or Data.IsBlocked(l) or not Data.MatchesMe(l) then return end
  pend[l.kind] = pend[l.kind] + 1
  if not pend.timer then pend.timer = true; C_Timer.After(5, FlushNotify) end
end

local function has(h, n) return n == nil or n == "" or lower(h or ""):find(lower(n), 1, true) ~= nil end
local function inRange(v, lo, hi)
  lo, hi = tonumber(lo), tonumber(hi)
  if lo and v < lo then return false end
  if hi and v > hi then return false end
  return true
end

local function Matches(l, f, words, s, now, rs)
  if Data.WrongFaction(l) or Data.WrongRuleset(l, rs) then return false end
  if f.activeOnly and Data.Status(l, now) ~= "active" then return false end
  if f.favOnly and not Data.IsFav(l.id) then return false end
  if f.hideContacted and GF.db.applications[l.id] then return false end
  if f.type and f.type ~= "Any" then
    if l.kind == "G" and l.gtype ~= f.type then return false end
    if l.kind == "P" and l.goal ~= f.type and l.goal ~= "Any" then return false end
  end
  if l.kind == "G" and f.focus and f.focus ~= "Any" and l.focus ~= f.focus then return false end
  if f.raid and f.raid ~= "Any" then
    if l.kind == "G" then
      if l.raid ~= f.raid and l.raid ~= "Multiple raids" then return false end
    elseif l.raid ~= f.raid and l.raid ~= "Any" then return false end
  end
  if f.stage and f.stage ~= "Any" and l.stage ~= "Any" and l.stage ~= f.stage then return false end
  if f.role and f.role ~= "Any" then
    if l.kind == "P" then
      local grp = RoleGroup(l.role)
      if grp and grp ~= f.role then return false end
    elseif not GuildWantsRole(l, f.role) then return false end
  end
  if f.class and f.class ~= "" then
    if l.kind == "P" then if not has(l.class, f.class) then return false end
    elseif l.needs ~= "" and not (has(l.needs, f.class) or has(l.desc, f.class)) then return false end
  end
  if l.kind == "P" and not has(l.spec, f.spec) then return false end
  if not inRange(l.kind == "P" and l.level or l.minLevel, f.lvlLo, f.lvlHi) then return false end
  if f.day and f.day ~= "" and Data.Overlap(f.day, l.days) == 0 then return false end
  if not has(l.times, f.time) or not has(l.tz, f.tz) then return false end
  if f.size and f.size ~= "Any" then
    if l.kind == "G" then if not has(l.size, f.size) then return false end
    elseif l.gsize ~= f.size and l.gsize ~= "Any" then return false end
  end
  if l.kind == "P" and f.exp and f.exp ~= "Any" and l.exp ~= f.exp then return false end
  if f.keyword and f.keyword ~= "" and not has((l.desc or "") .. " " .. (l.about or "") .. " " .. (l.needs or ""), f.keyword) then return false end
  if #words > 0 then
    local hay = { l.author }
    for _, def in ipairs(Data.Schema[l.kind]) do hay[#hay + 1] = tostring(l[def.k] or "") end
    hay = lower(table.concat(hay, " "))
    for _, w in ipairs(words) do if not hay:find(w, 1, true) then return false end end
  end
  return true
end

function Data.Query(kind, f)
  local out, now, s, rs = {}, time(), GF.db.settings, Data.GetRuleset()
  local words = {}
  for w in lower(f.search or ""):gmatch("%S+") do words[#words + 1] = w end
  for _, l in pairs(GF.db.listings) do
    if l.kind == kind and not Data.IsBlocked(l) and Matches(l, f, words, s, now, rs) then out[#out + 1] = l end
  end
  local my = Data.MyAd(kind == "G" and "P" or "G")
  local sched, rel = {}, {}
  for _, l in ipairs(out) do
    local days = (f.day and f.day ~= "") and f.day or (my and my.days) or ""
    local sc = 10 * Data.Overlap(days, l.days)
    if my and my.tz ~= "" and lower(my.tz) == lower(l.tz) then sc = sc + 3 end
    sched[l.id] = sc
    local r = sc
    if my then
      local g, p = kind == "G" and l or my, kind == "P" and l or my
      if GoalCompat(g, p) then r = r + 8 end
      if RoleCompat(g, p) then r = r + 6 end
      if g.raid ~= "Any" and g.raid == p.raid then r = r + 4 end
      if g.stage ~= "Any" and g.stage == p.stage then r = r + 3 end
    end
    if Data.IsFav(l.id) then r = r + 2 end
    if Data.IsChat(l) then r = r - 3 end
    rel[l.id] = r - (now - l.updated) / 86400 * 0.5
  end
  local sort = f.sort or "Newest"
  table.sort(out, function(a, b)
    if sort == "Oldest" then
      if a.updated ~= b.updated then return a.updated < b.updated end
    elseif sort == "Schedule match" then
      if sched[a.id] ~= sched[b.id] then return sched[a.id] > sched[b.id] end
      if a.updated ~= b.updated then return a.updated > b.updated end
    elseif sort == "Relevance" then
      if rel[a.id] ~= rel[b.id] then return rel[a.id] > rel[b.id] end
    else
      if a.updated ~= b.updated then return a.updated > b.updated end
    end
    return a.id < b.id
  end)
  return out
end

---------------------------------------------------------------- Export / import
function Data.Export()
  local lines = { "GFEXPORT2" }
  for _, l in pairs(GF.db.listings) do
    if not Data.IsBlocked(l) and not Data.IsChat(l) then lines[#lines + 1] = GF.Sync.Encode(l) end
  end
  return table.concat(lines, "\n")
end
function Data.Import(text)
  local n, bad = 0, 0
  for line in tostring(text):gmatch("[^\r\n]+") do
    line = strtrim(line)
    if line:sub(1, 2) == "L~" then
      local l = GF.Sync.Decode(line, "import")
      if l and Data.Merge(l, true, true) then n = n + 1 else bad = bad + 1 end
    end
  end
  return n, bad
end
