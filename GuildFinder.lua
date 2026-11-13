local ADDON, GF = ...
_G.GuildFinderAddon = GF
local Data = GF.Data
local lower = string.lower

-- Pulses the minimap button when new matching listings arrive.
function GF.Alert()
  local b = _G.GuildFinderMinimapButton
  if not b then return end
  if not b.gfGlow then
    local t = b:CreateTexture(nil, "OVERLAY", nil, 3)
    t:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    t:SetBlendMode("ADD"); t:SetAllPoints(); t:SetAlpha(0)
    b.gfGlow = t
  end
  local n = 0
  C_Timer.NewTicker(0.5, function() n = n + 1; b.gfGlow:SetAlpha(n % 2 == 1 and 1 or 0) end, 10)
end

local function HoursText(secs)
  if secs <= 0 then return "now (it has expired)" end
  local h = math.floor(secs / 3600)
  if h < 1 then return "under an hour" end
  return h .. (h == 1 and " hour" or " hours")
end

local function CheckExpiry()
  if not (GF.db and GF.db.settings.expiryWarn) then return end
  GF.warned = GF.warned or {}
  for _, l in ipairs(Data.ExpiringSoon(24)) do
    local key = l.id .. ":" .. l.ver
    if not GF.warned[key] then
      GF.warned[key] = true
      GF.Print(("Your %s advert (%s) expires in %s. Open /gfinder, go to My adverts and click Renew, or type /gfinder renew."):format(
        l.kind == "G" and "guild" or "player", l.name, HoursText(l.expires - time())))
    end
  end
end

local function OnEvent(event, ...)
  local arg1 = ...
  if event == "ADDON_LOADED" and arg1 == ADDON then
    GuildFinderDB = GuildFinderDB or {}
    GF.db = GuildFinderDB
    Data.Migrate(GF.db)
    GF.Debug("DB loaded, version", GF.db.dbVersion)

  elseif event == "PLAYER_LOGIN" then
    GF.me = UnitName("player")
    -- WoW Forever is realmless (you pick a ruleset), so the realm name may be empty. Fall back safely.
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
    realm = tostring(realm or ""):gsub("[%s%-']", "")
    if realm == "" then realm = "Forever" end
    GF.myRealm = realm
    GF.myFaction = (UnitFactionGroup("player")) -- "Alliance" or "Horde"
    GF.db.window = GF.db.window or {}
    Data.Cleanup()
    GF.Sync.Init()
    GF.UI.Init()
    GF.ready = true
    C_Timer.NewTicker(600, CheckExpiry)
    GF.Debug("Login init done:", GF.me, GF.myRealm, GF.myFaction, Data.GetRuleset())

  elseif event == "PLAYER_ENTERING_WORLD" and not GF.enteredOnce then
    GF.enteredOnce = true
    -- Auto-join the private sync channel, then ask other users for their listings.
    C_Timer.After(5, function() GF.Sync.JoinChannel(true) end)
    C_Timer.After(12, function()
      if GF.db.settings.autoRenew then
        for _, kind in ipairs({ "G", "P" }) do
          for _, l in ipairs(Data.Mine(kind)) do if l.active then Data.Renew(l.id) end end
        end
      end
      GF.Sync.Request(false)
    end)
    C_Timer.After(20, CheckExpiry)

  elseif event == "CHAT_MSG_CHANNEL" then
    -- Opt-in: read guild-recruitment lines from General / Trade chat. Never sends anything.
    if not (GF.ready and GF.db.settings.scanChat) then return end
    local text, sender, _, channelName = ...
    if type(text) ~= "string" or type(sender) ~= "string" then return end
    if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then return end
    if type(channelName) == "string" and lower(channelName):find("gfsync", 1, true) then return end
    if IsInInstance and IsInInstance() then return end
    Data.AddChatListing(text, sender)
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CHAT_MSG_CHANNEL" }) do
  ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event, ...)
  local ok, err = pcall(OnEvent, event, ...)
  if not ok then
    if GF.debugLog then GF.debugLog[#GF.debugLog + 1] = "ERROR " .. event .. ": " .. tostring(err) end
    print("|cffff4040Guild Finder error|r (" .. event .. "): " .. tostring(err))
  end
end)

---------------------------------------------------------------- Slash commands
-- NOTE: /gf and /guildfinder are Blizzard built-ins, so they are NOT used.
SLASH_GUILDFINDERBOARD1 = "/gfinder"
SLASH_GUILDFINDERBOARD2 = "/gfboard"
SLASH_GUILDFINDERBOARD3 = "/glf"

local function Help()
  GF.Print("Commands (use /gfinder, /gfboard or /glf):")
  print("  /gfinder - toggle the window")
  print("  /gfinder settings - open settings")
  print("  /gfinder refresh - request listings from other users")
  print("  /gfinder renew - renew all your active adverts")
  print("  /gfinder status - sync status")
  print("  /gfinder channel - test the sync channel")
  print("  /gfinder rejoin - try to (re)join the sync channel")
  print("  /gfinder debug [on|off|log] - toggle debug output / dump the log")
  print("  /gfinder reset - reset window position and size")
  print("  /gfmap - show or hide the minimap button")
end

SlashCmdList["GUILDFINDERBOARD"] = function(msg)
  local ok, err = pcall(function()
    msg = strtrim(msg or ""):lower()
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "toggle" then
      if GF.UI and GF.UI.Toggle then GF.UI.Toggle() else GF.Print("UI not loaded. Try /gfinder debug log") end
    elseif cmd == "settings" or cmd == "config" then
      if GF.UI and GF.UI.OpenSettings then GF.UI.OpenSettings() end
    elseif cmd == "refresh" or cmd == "sync" then
      local sent, why = GF.Sync.Request(true)
      GF.Print(sent and "Listing request sent on the sync channel." or why)
    elseif cmd == "renew" then
      local n = 0
      for _, kind in ipairs({ "G", "P" }) do
        for _, l in ipairs(Data.Mine(kind)) do if l.active then Data.Renew(l.id); n = n + 1 end end
      end
      GF.Print(n > 0 and ("Renewed %d advert(s)."):format(n) or "You have no active adverts to renew.")
      if GF.UI and GF.UI.RequestRefresh then GF.UI.RequestRefresh() end
    elseif cmd == "rejoin" then
      GF.Sync.JoinChannel(true)
      GF.Print("Trying to join " .. GF.Sync.ChannelName() .. "...")
    elseif cmd == "channel" then
      GF.Sync.JoinChannel(true)
      GF.Print("Sync channel diagnostics:")
      C_Timer.After(2.5, function() for _, line in ipairs(GF.Sync.Diag()) do print("  " .. line) end end)
    elseif cmd == "status" then
      local state, text, peers = GF.Sync.Status()
      GF.Print(("Sync: %s (%s), peers: %d, cached: %d, queued: %d, sent: %d, received: %d, rejected: %d"):format(
        state, tostring(text), peers, Data.Count(), #GF.Sync.queue,
        GF.Sync.stats.sent, GF.Sync.stats.recv, GF.Sync.stats.rejected))
      print("  faction: " .. tostring(GF.myFaction) .. "  ruleset: " .. Data.GetRuleset())
    elseif cmd == "debug" then
      if rest == "log" then
        GF.Print("Debug log (last " .. #GF.debugLog .. " lines):")
        for _, line in ipairs(GF.debugLog) do print("  " .. line) end
      else
        if rest == "on" then GF.db.debug = true
        elseif rest == "off" then GF.db.debug = false
        else GF.db.debug = not GF.db.debug end
        GF.Print("Debug output " .. (GF.db.debug and "ON" or "OFF"))
      end
    elseif cmd == "reset" then
      GF.db.window = {}
      if GF.UI and GF.UI.frame then
        GF.UI.frame:ClearAllPoints()
        GF.UI.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        GF.UI.frame:SetSize(GF.UI.DefaultSize())
      end
      GF.Print("Window position and size reset.")
    else
      Help()
    end
  end)
  if not ok then print("|cffff4040Guild Finder error|r: " .. tostring(err)) end
end
