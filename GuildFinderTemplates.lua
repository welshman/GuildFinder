local ADDON, GF = ...
local T = {}
GF.Templates = T
local lower = string.lower

T.DEFAULT_APP = "Hi [Guild Contact], I saw your Guild Finder advert for [Guild Name]. I am a [Class] [Spec] ([Role]), level [Level], looking for a [Guild Type] guild. My availability is [Availability]. I am interested because [Short Reason]. Would you have space for a player like me?"
T.DEFAULT_INVITE = "Hi [Player Name], I saw your Guild Finder advert. [Guild Name] is currently recruiting [Role/Class/Spec] players. We are a [Guild Type] guild focused on [Focus]. Our schedule is [Schedule]. Would you be interested in joining us?"

local function Join(...)
  local t = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v and v ~= "" and v ~= "Any" and v ~= 0 then t[#t + 1] = tostring(v) end
  end
  return table.concat(t, " ")
end

function T.Fill(tpl, map)
  local out = tpl:gsub("%[([^%]]+)%]", function(k)
    local v = map[lower(k)]
    if v == nil or v == "" then return nil end -- keep placeholder if unknown
    return v
  end)
  out = out:gsub("%(%s*%)", "")
  out = out:gsub("[ \t\r\n]+", " ")
  out = out:gsub(" ([%.,!?])", "%1")
  return strtrim(out)
end

-- One-line advert for pasting into General / Trade yourself (nothing is ever posted for you).
function T.ChatAd(l)
  local parts = {}
  if l.kind == "G" then
    local head = "<" .. l.name .. "> recruiting"
    local spots = {}
    if l.spotsT > 0 then spots[#spots + 1] = l.spotsT .. (l.spotsT > 1 and " tanks" or " tank") end
    if l.spotsH > 0 then spots[#spots + 1] = l.spotsH .. (l.spotsH > 1 and " healers" or " healer") end
    if l.spotsD > 0 then spots[#spots + 1] = l.spotsD .. " DPS" end
    if #spots > 0 then head = head .. ": " .. table.concat(spots, ", ")
    elseif l.needs ~= "" then head = head .. ": " .. l.needs end
    parts[#parts + 1] = head
    if l.raid ~= "Any" then parts[#parts + 1] = l.raid end
    if l.gtype ~= "Other" then parts[#parts + 1] = l.gtype end
    if l.minLevel > 0 then parts[#parts + 1] = "level " .. l.minLevel .. "+" end
    local sch = Join(l.days, l.times, l.tz)
    if sch ~= "" then parts[#parts + 1] = sch end
    parts[#parts + 1] = "whisper " .. l.contact
  else
    local who = "LF guild: level " .. l.level
    local c = Join(l.class, l.spec)
    if c ~= "" then who = who .. " " .. c end
    if l.role ~= "Any" then who = who .. " (" .. l.role .. ")" end
    parts[#parts + 1] = who
    if l.goal ~= "Any" then parts[#parts + 1] = l.goal end
    if l.raid ~= "Any" then parts[#parts + 1] = l.raid end
    local sch = Join(l.days, l.times, l.tz)
    if sch ~= "" then parts[#parts + 1] = sch end
    parts[#parts + 1] = "whisper " .. l.author
  end
  return table.concat(parts, " | ")
end

-- Returns message, hasOwnAdvert
function T.Build(l)
  local s, D = GF.db.settings, GF.Data
  if l.kind == "G" then
    local my = D.MyAd("P")
    local p = my or D.Defaults("P")
    local avail = Join(p.days, p.times, p.tz)
    local map = {
      ["guild contact"] = l.contact, ["guild name"] = l.name, class = p.class, spec = p.spec,
      role = (p.role ~= "Any" and p.role) or "flexible", level = tostring(p.level or ""),
      ["guild type"] = (my and my.goal ~= "Any" and my.goal) or l.gtype,
      availability = avail ~= "" and avail or "flexible", ["short reason"] = s.reason,
      raid = (l.raid ~= "Any" and l.raid) or nil,
    }
    return T.Fill(s.appTemplate, map), my ~= nil
  else
    local g = D.MyAd("G")
    local map = {
      ["player name"] = l.name,
      ["role/class/spec"] = Join(l.role, l.class, l.spec),
    }
    if g then
      map["guild name"], map["guild type"], map["focus"] = g.name, g.gtype, g.focus
      map["raid"] = (g.raid ~= "Any" and g.raid) or nil
      local sch = Join(g.days, g.times, g.tz)
      map["schedule"] = sch ~= "" and sch or "flexible"
    end
    return T.Fill(s.inviteTemplate, map), g ~= nil
  end
end
