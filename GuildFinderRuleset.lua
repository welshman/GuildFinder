local ADDON, GF = ...
local Data = GF.Data
local lower = string.lower

-- Ruleset is detected from the game itself (no option anywhere in the addon).
-- Forever exposes it through C_GameRules.IsGameRuleActive (Hardcore / RP / PvP, otherwise Normal).
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

-- The ruleset field is filled in automatically and never shown or editable.
for _, kind in ipairs({ "G", "P" }) do
  for _, def in ipairs(Data.Schema[kind]) do
    if def.k == "ruleset" then def.hidden = true; def.tip = "Set automatically from the game." end
  end
end

-- Only listings from your own ruleset are ever shown, stored or accepted
-- (players on different rulesets cannot interact in Forever anyway).
local origQuery = Data.Query
function Data.Query(kind, f)
  if GF.db then GF.db.settings.onlyRuleset = false end -- old setting, no longer used
  f.ruleset = "Any"
  local list = origQuery(kind, f)
  local rs, out = Data.GetRuleset(), {}
  for _, l in ipairs(list) do if l.ruleset == rs then out[#out + 1] = l end end
  return out
end

local origMerge = Data.Merge
function Data.Merge(l, relayed, allowOwn)
  if l.ruleset ~= Data.GetRuleset() then return nil, "other ruleset" end
  return origMerge(l, relayed, allowOwn)
end

local origSave = Data.Save
function Data.Save(kind, vals, id)
  local v = {}
  for k, x in pairs(vals) do v[k] = x end
  v.ruleset = Data.GetRuleset()
  return origSave(kind, v, id)
end

local origDefaults = Data.Defaults
function Data.Defaults(kind)
  local d = origDefaults(kind)
  d.ruleset = Data.GetRuleset()
  return d
end

local origCleanup = Data.Cleanup
function Data.Cleanup()
  origCleanup()
  local rs = Data.GetRuleset()
  for id, l in pairs(GF.db.listings) do
    if not Data.IsMine(l) and l.ruleset ~= rs then GF.db.listings[id] = nil end
  end
end
