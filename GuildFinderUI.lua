local ADDON, GF = ...
local UI = {}
GF.UI = UI
local Data, Sync, T, E = GF.Data, GF.Sync, GF.Templates, GF.Enums
local lower = string.lower

---------------------------------------------------------------- Theme (dark, flat, green accent)
local ACC = { .20, .74, .46 }
local COL = {
  bg = { .045, .05, .06, .98 }, side = { .07, .078, .09, 1 }, card = { .095, .105, .12, 1 },
  cardHover = { .13, .145, .165, 1 }, cardSel = { .075, .17, .13, 1 }, input = { .04, .045, .055, 1 },
  border = { .17, .19, .22, 1 }, text = { .92, .94, .96 }, dim = { .58, .62, .67 },
}
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local FACTION_COLOR = { Alliance = "4a8cff", Horde = "e0453a", Any = "bbbbbb" }
local STATUS = {
  active = { .2, .9, .4, "Active" }, inactive = { .6, .6, .6, "Paused" }, expired = { .9, .3, .3, "Expired" },
}
local C_GOLD, C_BLUE, C_PURPLE, C_YELLOW, C_GREY, C_GREEN, C_ORANGE = "e8c46a", "6cb4ff", "b79cff", "d9d27a", "a0a6ad", "5fe08a", "f0a050"
local DIMHEX = "8c969e"
local LAYOUT_VERSION = 2

-- Pages: guild, members (browse), fav, hist (saved lists), myP, myG (my adverts)
UI.page, UI.selected, UI.rows = "guild", nil, {}
GF.filters = {}
local function ResetFilters(kind)
  GF.filters[kind] = { type = "Any", focus = "Any", role = "Any", raid = "Any", stage = "Any", size = "Any", exp = "Any",
    sort = "Newest", activeOnly = true }
end
ResetFilters("G"); ResetFilters("P")

function UI.IsMine() return UI.page == "myP" or UI.page == "myG" end
function UI.IsSaved() return UI.page == "fav" or UI.page == "hist" end
function UI.IsBrowse() return UI.page == "guild" or UI.page == "members" end
function UI.ListKind()
  if UI.page == "guild" or UI.page == "myG" then return "G" end
  if UI.page == "members" or UI.page == "myP" then return "P" end
  return "G"
end
function UI.CreateKind()
  if UI.page == "guild" or UI.page == "myP" then return "P" end
  return "G"
end

---------------------------------------------------------------- Widgets
local function FS(parent, text, size, col)
  local tpl = size == "small" and "GameFontHighlightSmall" or size == "large" and "GameFontHighlightLarge" or "GameFontHighlight"
  local fs = parent:CreateFontString(nil, "OVERLAY", tpl)
  fs:SetText(text or "")
  col = col or COL.text
  fs:SetTextColor(col[1], col[2], col[3])
  return fs
end

local function Box(parent, bg, border)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop(FLAT)
  local b, e = bg or COL.card, border or COL.border
  f:SetBackdropColor(b[1], b[2], b[3], b[4] or 1)
  f:SetBackdropBorderColor(e[1], e[2], e[3], e[4] or 1)
  return f
end

local function Tip(f, title, text)
  f:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
    GameTooltip:Show()
  end)
  f:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- variants: normal, accent, danger, nav
local function Btn(parent, text, w, h, onclick, variant, tt, td)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 26)
  b:SetBackdrop(FLAT)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.label:SetPoint("CENTER")
  b.variant = variant or "normal"
  if b.variant == "nav" then
    b.label:ClearAllPoints(); b.label:SetPoint("LEFT", 16, 0); b.label:SetJustifyH("LEFT")
    b.bar = b:CreateTexture(nil, "OVERLAY"); b.bar:SetWidth(3)
    b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
  end
  function b:Paint()
    local v, h = self.variant, self.hover
    local bg, br, tc
    if v == "accent" then
      bg = h and { .13, .42, .27 } or { .10, .34, .22 }; br = ACC; tc = { 1, 1, 1 }
    elseif v == "danger" then
      bg = h and { .45, .12, .14 } or { .16, .08, .09 }; br = { .35, .12, .14 }; tc = { 1, .85, .85 }
    elseif v == "nav" then
      bg = self.active and { .11, .14, .15 } or (h and { .1, .11, .13 } or COL.side); br = bg
      tc = self.active and COL.text or (h and COL.text or COL.dim)
      self.bar:SetShown(self.active and true or false)
    else
      bg = h and { .17, .19, .22 } or { .12, .135, .155 }; br = h and { .3, .34, .38 } or COL.border; tc = COL.text
    end
    self:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    self:SetBackdropBorderColor(br[1], br[2], br[3], 1)
    self.label:SetTextColor(tc[1], tc[2], tc[3])
  end
  function b:SetText(t) self.label:SetText(t) end
  function b:GetText() return self.label:GetText() end
  b:SetText(text or "")
  b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
  b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
  if onclick then b:SetScript("OnClick", onclick) end
  b:Paint()
  if tt then Tip(b, tt, td) end
  return b
end

local function Edit(parent, w, max, placeholder)
  local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  e:SetSize(w, 26)
  e:SetBackdrop(FLAT)
  e:SetBackdropColor(COL.input[1], COL.input[2], COL.input[3], 1)
  e:SetBackdropBorderColor(COL.border[1], COL.border[2], COL.border[3], 1)
  e:SetFontObject(_G.GameFontHighlight)
  e:SetAutoFocus(false); e:SetMaxLetters(max or 100)
  e:SetTextInsets(8, 8, 0, 0)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  e:HookScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1); if s.ph then s.ph:Hide() end end)
  e:HookScript("OnEditFocusLost", function(s)
    s:SetBackdropBorderColor(COL.border[1], COL.border[2], COL.border[3], 1)
    if s.ph then s.ph:SetShown(s:GetText() == "") end
  end)
  if placeholder then
    e.ph = FS(e, placeholder, "small", COL.dim); e.ph:SetPoint("LEFT", 8, 0)
    e:HookScript("OnTextChanged", function(s) s.ph:SetShown(s:GetText() == "" and not s:HasFocus()) end)
  end
  return e
end

local function MultiEdit(parent, w, h, max)
  local c = Box(parent, COL.input, COL.border)
  c:SetSize(w, h)
  c:EnableMouse(true)
  local sf = CreateFrame("ScrollFrame", nil, c)
  sf:SetPoint("TOPLEFT", 8, -6); sf:SetPoint("BOTTOMRIGHT", -8, 6)
  local e = CreateFrame("EditBox", nil, sf)
  e:SetMultiLine(true); e:SetFontObject(_G.GameFontHighlight)
  e:SetAutoFocus(false); e:SetMaxLetters(max or 1000)
  e:SetWidth(w - 18); e:SetHeight(h - 12)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  sf:SetScrollChild(e)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(self, d)
    local range = math.max(0, e:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - d * 20)))
  end)
  e:HookScript("OnTextChanged", function(self)
    local lines = self.GetNumLines and self:GetNumLines() or 1
    self:SetHeight(math.max(h - 12, lines * 14 + 8))
  end)
  e:HookScript("OnEditFocusGained", function() c:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1) end)
  e:HookScript("OnEditFocusLost", function() c:SetBackdropBorderColor(COL.border[1], COL.border[2], COL.border[3], 1) end)
  c:SetScript("OnMouseDown", function() e:SetFocus() end)
  c.edit = e
  return c
end

-- Thin custom scroll area (mouse wheel + slim indicator)
local function Scroll(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(10, 10)
  sf:SetScrollChild(child)
  sf.child = child
  sf:EnableMouseWheel(true)
  local thumb = sf:CreateTexture(nil, "OVERLAY")
  thumb:SetWidth(3); thumb:SetColorTexture(1, 1, 1, .25); thumb:Hide()
  function sf:Update()
    local range = math.max(0, child:GetHeight() - self:GetHeight())
    local cur = math.min(self:GetVerticalScroll(), range)
    self:SetVerticalScroll(cur)
    if range <= 0 or self:GetHeight() <= 0 then thumb:Hide() return end
    local th = math.max(24, self:GetHeight() * self:GetHeight() / child:GetHeight())
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(cur / range) * (self:GetHeight() - th))
    thumb:Show()
  end
  sf:SetScript("OnMouseWheel", function(self, d)
    local range = math.max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - d * 48)))
    self:Update()
  end)
  sf:SetScript("OnSizeChanged", function(self, width) child:SetWidth(math.max(10, width - 8)); self:Update() end)
  return sf
end

local function Check(parent, label, get, set, tt, td)
  local c = CreateFrame("Button", nil, parent)
  c:SetSize(250, 22)
  c.box = Box(c, COL.input, COL.border); c.box:SetSize(16, 16); c.box:SetPoint("LEFT")
  c.tick = c.box:CreateTexture(nil, "OVERLAY")
  c.tick:SetPoint("TOPLEFT", 3, -3); c.tick:SetPoint("BOTTOMRIGHT", -3, 3)
  c.tick:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
  c.text = FS(c, label, "normal"); c.text:SetPoint("LEFT", c.box, "RIGHT", 8, 0)
  function c:Refresh() self.tick:SetShown(get() and true or false) end
  c:SetScript("OnClick", function(self) set(not get()); self:Refresh() end)
  c:SetScript("OnEnter", function(self) self.box:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1) end)
  c:SetScript("OnLeave", function(self) self.box:SetBackdropBorderColor(COL.border[1], COL.border[2], COL.border[3], 1) end)
  if tt then Tip(c, tt, td) end
  c:Refresh()
  return c
end

local function ShowMenu(anchor, opts, current, onpick)
  local m = UI.menu
  if not m then
    m = Box(UIParent, COL.input, { .3, .34, .38, 1 })
    m:SetFrameStrata("FULLSCREEN_DIALOG"); m:SetFrameLevel(50); m.items = {}
    m.catcher = CreateFrame("Button", nil, UIParent)
    m.catcher:SetAllPoints(UIParent); m.catcher:SetFrameStrata("FULLSCREEN_DIALOG"); m.catcher:SetFrameLevel(40)
    m.catcher:SetScript("OnClick", function() m:Hide() end)
    m.catcher:Hide()
    m:SetScript("OnHide", function() m.catcher:Hide() end)
    _G.GuildFinderMenu = m
    tinsert(UISpecialFrames, "GuildFinderMenu")
    m:Hide()
    UI.menu = m
  end
  for _, it in ipairs(m.items) do it:Hide() end
  local w = math.max(anchor:GetWidth(), 150)
  for i, v in ipairs(opts) do
    local it = m.items[i]
    if not it then
      it = CreateFrame("Button", nil, m)
      it:SetHeight(24)
      it.hl = it:CreateTexture(nil, "BACKGROUND"); it.hl:SetAllPoints(); it.hl:SetColorTexture(1, 1, 1, 0)
      it.text = FS(it, "", "normal"); it.text:SetPoint("LEFT", 10, 0)
      it:SetScript("OnEnter", function(s) s.hl:SetColorTexture(1, 1, 1, .08) end)
      it:SetScript("OnLeave", function(s) s.hl:SetColorTexture(1, 1, 1, 0) end)
      it:SetScript("OnClick", function(s) m:Hide(); if s.pick then s.pick(s.value) end end)
      m.items[i] = it
    end
    it:ClearAllPoints()
    it:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 24); it:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * 24)
    it.value, it.pick = v, onpick
    it.text:SetText(tostring(v))
    local c = (v == current) and ACC or COL.text
    it.text:SetTextColor(c[1], c[2], c[3])
    it:Show()
  end
  m:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
  m:SetSize(w, #opts * 24 + 4)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  m.catcher:Show(); m:Show()
end

local function Dropdown(parent, label, w, getOpts, get, set, tt, td)
  local b = Btn(parent, "", w, 26, nil, "normal")
  b.label:Hide()
  b.val = FS(b, "", "normal")
  b.arrow = FS(b, "v", "small", COL.dim); b.arrow:SetPoint("RIGHT", -8, 0)
  if label ~= "" then
    b.lab = FS(b, label, "small", COL.dim); b.lab:SetPoint("LEFT", 8, 0)
    b.val:SetPoint("RIGHT", -22, 0); b.val:SetJustifyH("RIGHT")
  else
    b.val:SetPoint("LEFT", 8, 0); b.val:SetPoint("RIGHT", -22, 0); b.val:SetJustifyH("LEFT")
  end
  b.val:SetWordWrap(false)
  function b:Refresh() self.val:SetText(tostring(get())) end
  b:SetScript("OnClick", function(self)
    ShowMenu(self, getOpts(), get(), function(v) set(v); self:Refresh() end)
  end)
  if tt then Tip(b, tt, td) end
  b:Refresh()
  return b
end

local function Modal(name, w, h, title)
  local m = Box(UIParent, COL.bg, { .25, .28, .32, 1 })
  m:SetSize(w, h); m:SetPoint("CENTER")
  m:SetFrameStrata("DIALOG"); m:SetFrameLevel(20)
  m:EnableMouse(true); m:SetMovable(true); m:RegisterForDrag("LeftButton"); m:SetClampedToScreen(true)
  m:SetScript("OnDragStart", m.StartMoving); m:SetScript("OnDragStop", m.StopMovingOrSizing)
  m.dim = CreateFrame("Frame", nil, UIParent)
  m.dim:SetAllPoints(UIParent); m.dim:SetFrameStrata("DIALOG"); m.dim:SetFrameLevel(10); m.dim:EnableMouse(true)
  local t = m.dim:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(0, 0, 0, .55)
  m.dim:Hide()
  m:HookScript("OnShow", function() m.dim:Show() end)
  m:HookScript("OnHide", function() m.dim:Hide() end)
  local bar = m:CreateTexture(nil, "OVERLAY"); bar:SetSize(4, 18); bar:SetPoint("TOPLEFT", 16, -16)
  bar:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
  m.title = FS(m, title, "large"); m.title:SetPoint("LEFT", bar, "RIGHT", 10, 0)
  m.close = Btn(m, "x", 26, 26, function() m:Hide() end, "normal")
  m.close:SetPoint("TOPRIGHT", -12, -12)
  _G[name] = m
  tinsert(UISpecialFrames, name)
  m:Hide()
  return m
end

local function Ago(t)
  local d = time() - t
  if d < 3600 then return math.max(1, math.floor(d / 60)) .. "m" end
  if d < 86400 then return math.floor(d / 3600) .. "h" end
  return math.floor(d / 86400) .. "d"
end
local function Tag(txt, hex) return "|cff" .. hex .. txt .. "|r" end
local function JoinTags(t) return table.concat(t, "   ") end
local function Sched(l)
  local t = {}
  for _, v in ipairs({ l.days, l.times, l.tz }) do if v and v ~= "" then t[#t + 1] = v end end
  return table.concat(t, " ")
end
local function RoleTag(role)
  local r = lower(role or "")
  if r == "any" or r == "" then return nil end
  return Tag(role, r == "tank" and "4fa3ff" or r == "healer" and "5fe08a" or "ff6a5f")
end
local function SpotsText(l)
  local o = {}
  if l.spotsT > 0 then o[#o + 1] = l.spotsT .. " Tank" end
  if l.spotsH > 0 then o[#o + 1] = l.spotsH .. " Healer" end
  if l.spotsD > 0 then o[#o + 1] = l.spotsD .. " DPS" end
  return table.concat(o, ", ")
end
local function NeedsTags(needs, out)
  local n = lower(needs or "")
  local any = false
  if n:find("tank") then out[#out + 1] = Tag("Tank", "4fa3ff"); any = true end
  if n:find("heal") then out[#out + 1] = Tag("Healer", "5fe08a"); any = true end
  if n:find("dps") or n:find("melee") or n:find("ranged") or n:find("damage") then out[#out + 1] = Tag("DPS", "ff6a5f"); any = true end
  if not any and n ~= "" then out[#out + 1] = Tag(Data.CutUtf8(needs, 22), C_GREY) end
end
local function ExpiresIn(l)
  local s = l.expires - time()
  if s <= 0 then return "expired" end
  if s < 3600 then return "under an hour" end
  if s < 86400 then return math.floor(s / 3600) .. "h" end
  return math.floor(s / 86400) .. " days"
end
local function RulesetName() return Data.GetRuleset() end

---------------------------------------------------------------- Listing rows (cards)
local function GetRow(i)
  local r = UI.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, UI.listScroll.child)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
  r.strip = r:CreateTexture(nil, "ARTWORK"); r.strip:SetWidth(3)
  r.strip:SetPoint("TOPLEFT"); r.strip:SetPoint("BOTTOMLEFT")
  r.l1 = FS(r, "", "normal"); r.l1:SetPoint("TOPLEFT", 14, -9); r.l1:SetPoint("TOPRIGHT", -62, -9)
  r.l1:SetJustifyH("LEFT"); r.l1:SetWordWrap(false)
  r.l2 = FS(r, "", "small", COL.dim); r.l2:SetPoint("TOPLEFT", 14, -31); r.l2:SetPoint("TOPRIGHT", -10, -31)
  r.l2:SetJustifyH("LEFT"); r.l2:SetWordWrap(false)
  r.age = FS(r, "", "small", COL.dim); r.age:SetPoint("TOPRIGHT", -12, -10)
  r.fav = r:CreateTexture(nil, "OVERLAY"); r.fav:SetSize(7, 7); r.fav:SetPoint("RIGHT", r.age, "LEFT", -6, 0)
  r.fav:SetColorTexture(.91, .77, .42, 1)
  function r:Paint()
    local c = (self.id == UI.selected) and COL.cardSel or (self.hover and COL.cardHover or COL.card)
    self.bg:SetColorTexture(c[1], c[2], c[3], 1)
  end
  r:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
  r:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
  r:SetScript("OnClick", function(s) UI.Select(s.id) end)
  UI.rows[i] = r
  return r
end

local function RenderRow(r, l, compact, h, i)
  r.id = l.id
  r:SetHeight(h)
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", UI.listScroll.child, "TOPLEFT", 0, -(i - 1) * (h + 4))
  r:SetPoint("TOPRIGHT", UI.listScroll.child, "TOPRIGHT", 0, -(i - 1) * (h + 4))
  local st = STATUS[Data.Status(l)]
  r.strip:SetColorTexture(st[1], st[2], st[3], 1)
  local line1, tags = nil, {}
  if l.kind == "G" then
    line1 = l.name
    tags[#tags + 1] = Tag(l.gtype, C_GOLD)
    tags[#tags + 1] = Tag(l.focus, C_BLUE)
    if l.raid ~= "Any" then tags[#tags + 1] = Tag(l.raid, C_ORANGE) end
    local spots = SpotsText(l)
    if spots ~= "" then tags[#tags + 1] = Tag("Needs " .. spots, C_GREEN) else NeedsTags(l.needs, tags) end
    if l.stage ~= "Any" then tags[#tags + 1] = Tag(l.stage, C_GREY) end
    if Sched(l) ~= "" then tags[#tags + 1] = Tag(Sched(l), C_PURPLE) end
    if l.minLevel > 0 then tags[#tags + 1] = Tag("Level " .. l.minLevel .. "+", C_YELLOW) end
  else
    line1 = ("%s   |cff%sLevel %d %s %s|r"):format(l.name, DIMHEX, l.level, l.class, l.spec)
    local rt = RoleTag(l.role); if rt then tags[#tags + 1] = rt end
    tags[#tags + 1] = Tag(l.goal, C_GOLD)
    if l.raid ~= "Any" then tags[#tags + 1] = Tag(l.raid, C_ORANGE) end
    tags[#tags + 1] = Tag(l.exp, C_BLUE)
    if Sched(l) ~= "" then tags[#tags + 1] = Tag(Sched(l), C_PURPLE) end
    if l.gsize ~= "Any" then tags[#tags + 1] = Tag(l.gsize .. " guild", C_GREY) end
  end
  if Data.IsChat(l) then tags[#tags + 1] = Tag("From chat", C_ORANGE) end
  if Data.GetContacted(l.id) then tags[#tags + 1] = Tag("Contacted", C_GREY) end
  if compact then
    r.l1:SetText(line1 .. "   " .. JoinTags(tags)); r.l2:Hide()
  else
    r.l1:SetText(line1); r.l2:SetText(JoinTags(tags)); r.l2:Show()
  end
  r.age:SetText(Ago(l.updated))
  r.fav:SetShown(Data.IsFav(l.id))
  r:Paint()
  r:Show()
end

function UI.Refresh()
  local f = UI.frame
  if not f or not f:IsShown() then return end
  local kind = UI.ListKind()
  local list
  if UI.page == "fav" then list = Data.ListFrom(GF.db.favorites)
  elseif UI.page == "hist" then list = Data.ListFrom(GF.db.applications)
  elseif UI.IsMine() then list = Data.Mine(kind)
  else list = Data.Query(kind, GF.filters[kind]) end
  UI.list = list
  local compact = GF.db.settings.compact
  local h = compact and 30 or 54
  local shown = math.min(#list, 200)
  for i = 1, shown do RenderRow(GetRow(i), list[i], compact, h, i) end
  for i = shown + 1, #UI.rows do UI.rows[i]:Hide() end
  UI.listScroll.child:SetHeight(math.max(1, shown * (h + 4)))
  UI.listScroll:Update()
  UI.empty:SetShown(#list == 0)
  if UI.page == "fav" then
    UI.empty:SetText("No favourites yet.\nSelect a listing and click + Favourite.")
    UI.pageTitle:SetText("Favourites")
    UI.pageSub:SetText(("%d saved  |  private, only on your computer"):format(#list))
  elseif UI.page == "hist" then
    UI.empty:SetText("You haven't contacted anyone yet.\nWhen you click Whisper, the listing shows up here.")
    UI.pageTitle:SetText("Contacted")
    UI.pageSub:SetText(("%d contacted  |  history is kept for 60 days"):format(#list))
  elseif UI.IsMine() then
    UI.empty:SetText("You have no adverts here yet.\nClick Create to post one.\nIt appears for other Guild Finder users on your faction and ruleset.")
    UI.pageTitle:SetText(kind == "P" and "My Looking-For-Guild advert" or "My guild adverts")
    UI.pageSub:SetText("Edit, pause, renew or delete your own adverts.")
  else
    UI.empty:SetText("Nothing found.\nTry fewer filters, press Refresh, or post your own advert.\nYour own adverts always work, even if nobody else is online.")
    UI.pageTitle:SetText(kind == "G" and "Find a Guild" or "Find Members")
    UI.pageSub:SetText(("%d %s  |  %s, %s"):format(#list, kind == "G" and (#list == 1 and "guild" or "guilds") or (#list == 1 and "player" or "players"), GF.myFaction or "your faction", RulesetName()))
  end
  UI.createBtn:SetText(UI.CreateKind() == "P" and "+ Looking-for-guild advert" or "+ Guild advert")
  if UI.selected and not GF.db.listings[UI.selected] then UI.selected = nil end
  UI.ShowDetails(UI.selected)
  UI.UpdateStatus()
end

function UI.RequestRefresh()
  UI.token = (UI.token or 0) + 1
  local t = UI.token
  C_Timer.After(0.25, function() if t == UI.token then UI.Refresh() end end)
end

function UI.Select(id)
  UI.selected = id
  for _, r in ipairs(UI.rows) do r:Paint() end
  UI.ShowDetails(id)
end

---------------------------------------------------------------- Details panel
local function DetailText(l)
  local out = {}
  for _, def in ipairs(Data.Schema[l.kind]) do
    local v = l[def.k]
    if def.k ~= "name" and not def.hidden and v ~= nil and v ~= "" and v ~= 0 then
      out[#out + 1] = ("|cff%s%s|r\n%s\n"):format(DIMHEX, def.label, tostring(v))
    end
  end
  out[#out + 1] = ("|cff%sContact|r\nWhisper %s\n"):format(DIMHEX, l.kind == "G" and l.contact or l.author)
  out[#out + 1] = ("|cff%sPosted by|r\n%s\n"):format(DIMHEX, l.author)
  out[#out + 1] = ("|cff%sUpdated|r\n%s   (expires %s)"):format(DIMHEX, date("%d %b %H:%M", l.updated), date("%d %b", l.expires))
  return table.concat(out, "\n")
end

-- WoW Forever is realmless, so whispers go to the plain character name.
local function TargetName(l) return l.kind == "G" and l.contact or l.author end
local function MaxMsgLen(l)
  if Data.IsMine(l) then return 255 end
  return 255 - #("/w " .. TargetName(l) .. " ")
end
local function FlatMessage()
  local m = UI.details.msg.edit:GetText():gsub("[\r\n]+", " ")
  return strtrim(m)
end
local function Sel() return UI.selected and GF.db.listings[UI.selected] end

function UI.UpdateCounter()
  local d, l = UI.details, Sel()
  if not l then return end
  local n, max = #FlatMessage(), MaxMsgLen(l)
  d.counter:SetText(("%s%d / %d|r"):format(n > max and "|cffff5050" or ("|cff" .. DIMHEX), n, max))
end

function UI.DoWhisper()
  local l = Sel()
  if not l then return end
  local prefix = "/w " .. TargetName(l) .. " "
  local msg = FlatMessage()
  local max = 255 - #prefix
  if #msg > max then msg = Data.CutUtf8(msg, max); GF.Print("Message was longer than the chat limit and has been trimmed. Edit it if needed.") end
  -- Opens the chat box pre-filled. You must press Enter to send. Nothing is sent automatically.
  if ChatFrame_OpenChat then ChatFrame_OpenChat(prefix .. msg, DEFAULT_CHAT_FRAME)
  elseif ChatFrame_SendTell then ChatFrame_SendTell(TargetName(l)) end
  Data.MarkContacted(l)
  UI.RequestRefresh()
end

function UI.DoCopy()
  local l = Sel()
  local mine = l and Data.IsMine(l)
  UI.TextBox(mine and "Copy chat advert" or "Copy message", FlatMessage(), nil, nil,
    mine and "Press Ctrl+C to copy, then paste it into General or Trade yourself." or "Press Ctrl+C to copy, then Esc.")
end

function UI.ShowDetails(id)
  local d = UI.details
  local l = id and GF.db.listings[id]
  d.group:SetShown(l ~= nil)
  d.empty:SetShown(l == nil)
  if not l then return end
  local mine = Data.IsMine(l)
  local st = STATUS[Data.Status(l)]
  local fc = FACTION_COLOR[l.faction] or "bbbbbb"
  d.name:SetText("|cff" .. fc .. l.name .. "|r")
  d.statusDot:SetColorTexture(st[1], st[2], st[3], 1)
  local extra = ""
  if mine then extra = "  |  expires in " .. ExpiresIn(l) end
  if Data.IsChat(l) then extra = extra .. "  |  from chat, unverified" end
  local c = Data.GetContacted(l.id)
  if c then extra = extra .. "  |  contacted " .. Ago(c.t) .. " ago" end
  d.statusText:SetText(st[4] .. "  |  " .. (l.kind == "G" and "Guild" or "Player") .. extra)
  d.bodyText:SetText(DetailText(l))
  d.info.child:SetHeight(d.bodyText:GetStringHeight() + 12)
  d.info:Update()

  d.fav:SetShown(not mine)
  d.fav.variant = Data.IsFav(l.id) and "accent" or "normal"
  d.fav:SetText(Data.IsFav(l.id) and "Favourited" or "+ Favourite"); d.fav:Paint()
  d.whisper:SetShown(not mine)
  d.safety:SetShown(not mine); d.own:SetShown(mine)
  d.noteLabel:SetShown(not mine); d.note:SetShown(not mine)
  d.info:ClearAllPoints()
  d.info:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -62)
  d.info:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, mine and 290 or 342)
  local msg, hasAd
  if mine then
    msg = T.ChatAd(l)
    d.msgLabel:SetText("Chat advert (copy it, paste into General or Trade)")
    d.warn:SetText("")
    d.copy:SetText("Copy chat advert")
  else
    msg, hasAd = T.Build(l)
    d.msgLabel:SetText("Message preview (edit it, then send)")
    d.warn:SetText(hasAd and "" or (l.kind == "G" and "Tip: create a Looking-for-guild advert to auto-fill more." or "Tip: create a guild advert to auto-fill guild details."))
    d.copy:SetText(l.kind == "G" and "Copy application" or "Copy invite message")
    d.whisper:SetText(l.kind == "G" and "Whisper guild contact" or "Whisper player")
    d.note:SetText(GF.db.notes[l.id] or ""); d.note:SetCursorPosition(0)
  end
  d.msg.edit:SetText(msg); d.msg.edit:SetCursorPosition(0)
  UI.UpdateCounter()
  if mine then d.toggle:SetText(l.active and "Pause" or "Activate") end
end

local function BuildDetails(f)
  local d = Box(f, COL.side, COL.border)
  d:SetWidth(300)
  d:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -52)
  d:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 14)
  UI.details = d
  d.empty = FS(d, "Select a listing to see the details", "normal", COL.dim); d.empty:SetPoint("CENTER")
  local g = CreateFrame("Frame", nil, d); g:SetAllPoints(); d.group = g

  d.name = FS(g, "", "large"); d.name:SetPoint("TOPLEFT", 14, -14); d.name:SetPoint("TOPRIGHT", -118, -14)
  d.name:SetJustifyH("LEFT"); d.name:SetWordWrap(false)
  d.fav = Btn(g, "+ Favourite", 98, 24, function()
    local l = Sel(); if l then Data.ToggleFav(l.id); UI.Refresh() end
  end, "normal", "Favourite", "Saves this listing to your private Favourites list.")
  d.fav:SetPoint("TOPRIGHT", -14, -14)
  d.statusDot = g:CreateTexture(nil, "OVERLAY"); d.statusDot:SetSize(8, 8); d.statusDot:SetPoint("TOPLEFT", 14, -42)
  d.statusText = FS(g, "", "small", COL.dim); d.statusText:SetPoint("LEFT", d.statusDot, "RIGHT", 6, 0)
  d.statusText:SetPoint("RIGHT", g, "RIGHT", -10, 0); d.statusText:SetJustifyH("LEFT"); d.statusText:SetWordWrap(false)

  d.info = Scroll(g)
  d.bodyText = FS(d.info.child, "", "small")
  d.bodyText:SetPoint("TOPLEFT"); d.bodyText:SetPoint("TOPRIGHT", -4, 0)
  d.bodyText:SetJustifyH("LEFT"); d.bodyText:SetJustifyV("TOP"); d.bodyText:SetWordWrap(true)

  d.noteLabel = FS(g, "Your private note", "small", COL.dim); d.noteLabel:SetPoint("BOTTOMLEFT", 14, 322)
  d.note = Edit(g, 272, 80, "Only you can see this")
  d.note:SetPoint("BOTTOMLEFT", 14, 294)
  d.note:HookScript("OnTextChanged", function(self, user)
    if not user then return end
    local l = Sel()
    if l then
      local t = strtrim(self:GetText())
      GF.db.notes[l.id] = (t ~= "") and t or nil
    end
  end)

  d.warn = FS(g, "", "small", { .95, .7, .3 }); d.warn:SetPoint("BOTTOMLEFT", 14, 264); d.warn:SetWidth(272); d.warn:SetJustifyH("LEFT")
  d.msgLabel = FS(g, "", "small", COL.dim); d.msgLabel:SetPoint("BOTTOMLEFT", 14, 246)
  d.msg = MultiEdit(g, 272, 96, 600); d.msg:SetPoint("BOTTOMLEFT", 14, 146)
  d.msg.edit:HookScript("OnTextChanged", function(_, user) if user then UI.UpdateCounter() end end)
  d.counter = FS(g, "", "small", COL.dim); d.counter:SetPoint("BOTTOMRIGHT", -14, 130)

  d.whisper = Btn(g, "Whisper", 272, 32, UI.DoWhisper, "accent", "Whisper",
    "Opens a whisper with the message filled in. You press Enter to send it. Nothing is sent automatically.")
  d.whisper:SetPoint("BOTTOMLEFT", 14, 92)
  d.copy = Btn(g, "Copy", 272, 28, UI.DoCopy, "normal", "Copy message", "Shows the message so you can press Ctrl+C.")
  d.copy:SetPoint("BOTTOMLEFT", 14, 56)

  d.safety = CreateFrame("Frame", nil, g); d.safety:SetSize(272, 28); d.safety:SetPoint("BOTTOMLEFT", 14, 14)
  local hide = Btn(d.safety, "Hide", 86, 26, function()
    local l = Sel(); if l then Data.Block(l, false); UI.selected = nil; UI.Refresh() end
  end, "normal", "Hide listing", "Hides this listing on your client only.")
  hide:SetPoint("LEFT")
  local block = Btn(d.safety, "Block author", 90, 26, function()
    local l = Sel(); if l then Data.Block(l, true); UI.selected = nil; UI.Refresh() end
  end, "normal", "Block author", "Hides everything from this author on your client.")
  block:SetPoint("LEFT", 91, 0)
  local report = Btn(d.safety, "Report", 86, 26, function()
    local l = Sel()
    if l then
      Data.Block(l, false); UI.selected = nil; UI.Refresh()
      GF.Print("Listing hidden. There is no server report for addon adverts. Use the in-game report tools for abusive whispers.")
    end
  end, "normal", "Report", "Hides the listing. Use Blizzard's report tools for abuse.")
  report:SetPoint("LEFT", 186, 0)

  d.own = CreateFrame("Frame", nil, g); d.own:SetSize(272, 28); d.own:SetPoint("BOTTOMLEFT", 14, 14)
  local edit = Btn(d.own, "Edit", 62, 26, function() local l = Sel(); if l then UI.OpenEditor(l.kind, l.id) end end, "accent", "Edit", "Edit your advert.")
  edit:SetPoint("LEFT")
  d.toggle = Btn(d.own, "Pause", 66, 26, function()
    local l = Sel(); if l then Data.SetActive(l.id, not l.active); UI.Refresh() end
  end, "normal", "Pause / Activate", "Hide or show your advert to other players.")
  d.toggle:SetPoint("LEFT", 67, 0)
  local renew = Btn(d.own, "Renew", 66, 26, function()
    local l = Sel(); if l then Data.Renew(l.id); UI.Refresh() end
  end, "normal", "Renew", "Extends the expiry and shares your advert again.")
  renew:SetPoint("LEFT", 138, 0)
  local del = Btn(d.own, "Delete", 62, 26, function()
    local l = Sel(); if l then UI.pendingDelete = l.id; StaticPopup_Show("GUILDFINDER_DELETE", l.name) end
  end, "danger", "Delete", "Permanently deletes your advert (asks first).")
  del:SetPoint("LEFT", 210, 0)
end

---------------------------------------------------------------- Pop-ups
function UI.TextBox(title, text, acceptLabel, onAccept, hint)
  local tb = UI.textBox
  if not tb then
    tb = Modal("GuildFinderTextBox", 560, 340, "")
    tb.hint = FS(tb, "", "small", COL.dim); tb.hint:SetPoint("TOPLEFT", 20, -48)
    tb.box = MultiEdit(tb, 520, 200, 100000); tb.box:SetPoint("TOPLEFT", 20, -70)
    tb.accept = Btn(tb, "OK", 110, 28, function() if tb.onAccept then tb.onAccept(tb.box.edit:GetText()) end tb:Hide() end, "accent")
    tb.accept:SetPoint("BOTTOMRIGHT", -140, 16)
    tb.closeBtn = Btn(tb, "Close", 110, 28, function() tb:Hide() end, "normal")
    tb.closeBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    UI.textBox = tb
  end
  tb.title:SetText(title)
  tb.hint:SetText(hint or "")
  tb.box.edit:SetText(text or "")
  tb.onAccept = onAccept
  tb.accept:SetShown(onAccept ~= nil)
  if acceptLabel then tb.accept:SetText(acceptLabel) end
  tb:Show()
  tb.box.edit:SetFocus()
  if not onAccept then tb.box.edit:HighlightText() end
end

StaticPopupDialogs["GUILDFINDER_DELETE"] = {
  text = "Delete your Guild Finder advert for %s?\nThis cannot be undone.",
  button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  OnAccept = function()
    local ok, err = Data.Delete(UI.pendingDelete)
    if not ok then GF.Print(err) end
    UI.selected = nil
    UI.Refresh()
  end,
}
StaticPopupDialogs["GUILDFINDER_CLEAR"] = {
  text = "Clear all cached listings from other players?\nYour own adverts are kept.",
  button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  OnAccept = function() Data.ClearCache(); UI.selected = nil; UI.Refresh(); GF.Print("Cache cleared.") end,
}

---------------------------------------------------------------- Advert editor (scrollable)
local function BuildForm(kind)
  local form = CreateFrame("Frame", nil, UI.editor.scroll.child)
  form:SetPoint("TOPLEFT")
  form.w = {}
  local row, col = 0, 0
  for _, def in ipairs(Data.Schema[kind]) do
    if not def.hidden then
      if def.wide and col == 1 then row = row + 1; col = 0 end
      local x = (def.wide or col == 0) and 0 or 320
      local y = -row * 52
      local label = FS(form, def.label, "small", COL.dim); label:SetPoint("TOPLEFT", x, y)
      local width = def.wide and 620 or 300
      local w = {}
      if def.t == "e" then
        local b = Dropdown(form, "", width, function() return E[def.enum] end, function() return w.value end,
          function(v) w.value = v end, def.label, def.tip)
        b:SetPoint("TOPLEFT", x, y - 16)
        w.get = function() return w.value end
        w.set = function(v) w.value = v or E[def.enum][1]; b:Refresh() end
      else
        local e = Edit(form, width, def.t == "n" and 3 or def.max)
        e:SetPoint("TOPLEFT", x, y - 16)
        if def.t == "n" then e:SetNumeric(true) end
        Tip(e, def.label, def.tip)
        w.get = function() return e:GetText() end
        w.set = function(v) e:SetText((v == nil or v == 0) and "" or tostring(v)); e:SetCursorPosition(0) end
      end
      form.w[def.k] = w
      if def.wide then row = row + 1; col = 0
      elseif col == 0 then col = 1 else col = 0; row = row + 1 end
    end
  end
  if col == 1 then row = row + 1 end
  form:SetSize(640, row * 52 + 8)
  return form
end

function UI.BuildEditor()
  local ed = Modal("GuildFinderEditor", 700, 600, "")
  ed.scroll = Scroll(ed)
  ed.scroll:SetPoint("TOPLEFT", 20, -58); ed.scroll:SetPoint("BOTTOMRIGHT", -30, 64)
  ed.forms = {}
  ed.err = FS(ed, "", "normal", { 1, .4, .4 }); ed.err:SetPoint("BOTTOMLEFT", 20, 50); ed.err:SetWidth(660); ed.err:SetJustifyH("LEFT")
  ed.fill = Btn(ed, "Fill from my guild", 150, 26, function()
    local gname = GetGuildInfo and GetGuildInfo("player")
    if not gname then ed.err:SetText("You are not in a guild.") return end
    local f = ed.forms.G
    if f then f.w.name.set(gname); f.w.contact.set(GF.me) end
    ed.err:SetText("")
  end, "normal", "Fill from my guild", "Fills in your guild's name and sets you as the contact.")
  ed.fill:SetPoint("TOPRIGHT", -48, -12)
  ed.save = Btn(ed, "Save advert", 140, 30, function() UI.SaveEditor() end, "accent", "Save", "Saves and shares the advert with other Guild Finder users on your faction and ruleset.")
  ed.save:SetPoint("BOTTOMRIGHT", -170, 14)
  ed.cancel = Btn(ed, "Cancel", 130, 30, function() ed:Hide() end, "normal")
  ed.cancel:SetPoint("BOTTOMRIGHT", -20, 14)
  UI.editor = ed
end

function UI.OpenEditor(kind, id)
  if not id then
    local ok, err = Data.CanCreate(kind)
    if not ok then GF.Print(err) return end
  end
  local ed = UI.editor
  ed.kind, ed.id = kind, id
  ed.forms[kind] = ed.forms[kind] or BuildForm(kind)
  for k, fr in pairs(ed.forms) do fr:SetShown(k == kind) end
  local src = id and GF.db.listings[id] or Data.Defaults(kind)
  for _, def in ipairs(Data.Schema[kind]) do
    local wdg = ed.forms[kind].w[def.k]
    if wdg then wdg.set(src[def.k]) end
  end
  ed.scroll.child:SetHeight(ed.forms[kind]:GetHeight())
  ed.scroll:SetVerticalScroll(0)
  ed.scroll:Update()
  ed.fill:SetShown(kind == "G")
  ed:SetScale(math.min(1, (UIParent:GetHeight() - 30) / 600))
  ed.title:SetText((id and "Edit " or "New ") .. (kind == "G" and "guild advert" or "looking-for-guild advert")
    .. "  |cff" .. DIMHEX .. (GF.myFaction or "") .. ", " .. RulesetName() .. "|r")
  ed.err:SetText("")
  ed:Show()
end

function UI.SaveEditor()
  local ed = UI.editor
  local vals = {}
  for k, w in pairs(ed.forms[ed.kind].w) do vals[k] = w.get() end
  local l, err = Data.Save(ed.kind, vals, ed.id)
  if not l then ed.err:SetText(err or "Could not save.") return end
  ed:Hide()
  UI.selected = l.id
  UI.SetPage(l.kind == "P" and "myP" or "myG", l.id)
  GF.Print("Advert saved and shared.")
end

---------------------------------------------------------------- Filters
local function WithAny(t) local o = { "Any" }; for _, v in ipairs(t) do o[#o + 1] = v end; return o end
local function FilterDefs(kind)
  -- share = fraction of the quick bar each dropdown gets (widths adapt to the window size)
  local quick = {
    { k = "type", t = "drop", label = kind == "G" and "Type" or "Wants", share = 0.36, opts = kind == "G" and WithAny(E.guildTypes) or E.goals, tip = kind == "G" and "Guild type." or "The kind of guild the player wants." },
    { k = "role", t = "drop", label = "Role", share = 0.24, opts = { "Any", "Tank", "Healer", "DPS" }, tip = kind == "G" and "Guilds with open spots for this role." or "Players with this role." },
    { k = "raid", t = "drop", label = "Raid", share = 0.40, opts = E.raids, tip = "Barrow Deeps (10), Hyjal Summit (20) or Onyxia's Lair (40)." },
  }
  local adv = {}
  adv[#adv + 1] = { k = "stage", t = "drop", label = "Levelling / level 60", opts = E.stages, tip = "Levelling characters or level 60 characters." }
  if kind == "G" then adv[#adv + 1] = { k = "focus", t = "drop", label = "Focus", opts = WithAny(E.foci), tip = "Primary focus of the guild." } end
  adv[#adv + 1] = { k = "class", t = "edit", label = "Class", tip = "Class name." }
  if kind == "P" then adv[#adv + 1] = { k = "spec", t = "edit", label = "Talent spec", tip = "Spec name." } end
  adv[#adv + 1] = { k = "lvl", t = "range", label = kind == "G" and "Level requirement (from - to)" or "Level (from - to)", tip = "Level range, 1-60." }
  adv[#adv + 1] = { k = "day", t = "edit", label = "Day (Tue, weekend...)", tip = "Matches adverts sharing at least one day." }
  adv[#adv + 1] = { k = "time", t = "edit", label = "Time (20:00...)", tip = "Text match on times." }
  adv[#adv + 1] = { k = "tz", t = "edit", label = "Timezone", tip = "e.g. GMT." }
  adv[#adv + 1] = { k = "size", t = "drop", label = "Guild size", opts = E.sizes, tip = "Guild size." }
  if kind == "P" then adv[#adv + 1] = { k = "exp", t = "drop", label = "Experience", opts = WithAny(E.exp), tip = "Player experience level." } end
  adv[#adv + 1] = { k = "keyword", t = "edit", label = "Keyword", tip = "Searches description / about me / class notes." }
  adv[#adv + 1] = { k = "sort", t = "drop", label = "Sort by", opts = { "Newest", "Oldest", "Schedule match", "Relevance" }, tip = "Schedule match compares days with your own advert." }
  adv[#adv + 1] = { k = "activeOnly", t = "check", label = "Active only", tip = "Hide paused and expired adverts." }
  adv[#adv + 1] = { k = "favOnly", t = "check", label = "Favourites only", tip = "Only show listings you have favourited." }
  adv[#adv + 1] = { k = "hideContacted", t = "check", label = "Hide contacted", tip = "Hide listings you have already whispered." }
  return quick, adv
end

local function BuildFilters(kind, quickParent, advParent)
  local g = { sync = {} }
  local function flt() return GF.filters[kind] end
  local quick, adv = FilterDefs(kind)
  g.quick = CreateFrame("Frame", nil, quickParent)
  g.quick:SetAllPoints()
  g.drops = {}
  for i, d in ipairs(quick) do
    local b = Dropdown(g.quick, d.label, 120, function() return d.opts end,
      function() return flt()[d.k] or d.opts[1] end,
      function(v) flt()[d.k] = v; UI.RequestRefresh() end, d.label, d.tip)
    b.share = d.share
    g.drops[i] = b
    g.sync[#g.sync + 1] = function() b:Refresh() end
  end
  local function LayoutQuick()
    local avail = g.quick:GetWidth()
    if not avail or avail < 100 then return end
    local gap = 8
    local usable = avail - gap * (#g.drops - 1)
    local x = 0
    for _, b in ipairs(g.drops) do
      local w = math.floor(usable * b.share)
      b:ClearAllPoints(); b:SetPoint("LEFT", g.quick, "LEFT", x, 0); b:SetWidth(w)
      x = x + w + gap
    end
  end
  g.quick:SetScript("OnSizeChanged", LayoutQuick)
  g.quick:HookScript("OnShow", LayoutQuick)
  g.LayoutQuick = LayoutQuick

  g.adv = CreateFrame("Frame", nil, advParent)
  g.adv:SetAllPoints()
  local col, row = 0, 0
  for _, d in ipairs(adv) do
    local cx, cy = 18 + col * 160, -52 - row * 48
    local lab = FS(g.adv, d.t == "check" and "" or d.label, "small", COL.dim); lab:SetPoint("TOPLEFT", cx, cy)
    if d.t == "drop" then
      local b = Dropdown(g.adv, "", 150, function() return d.opts end,
        function() return flt()[d.k] or d.opts[1] end,
        function(v) flt()[d.k] = v; UI.RequestRefresh() end, d.label, d.tip)
      b:SetPoint("TOPLEFT", cx, cy - 16)
      g.sync[#g.sync + 1] = function() b:Refresh() end
    elseif d.t == "edit" then
      local e = Edit(g.adv, 150, 40)
      e:SetPoint("TOPLEFT", cx, cy - 16)
      Tip(e, d.label, d.tip)
      e:HookScript("OnTextChanged", function(self, user)
        if user then flt()[d.k] = self:GetText(); UI.RequestRefresh() end
      end)
      g.sync[#g.sync + 1] = function() e:SetText(flt()[d.k] or "") end
    elseif d.t == "range" then
      for i, suffix in ipairs({ "Lo", "Hi" }) do
        local e = Edit(g.adv, 70, 3)
        e:SetPoint("TOPLEFT", cx + (i - 1) * 80, cy - 16)
        e:SetNumeric(true)
        Tip(e, d.label, d.tip)
        local key = d.k .. suffix
        e:HookScript("OnTextChanged", function(self, user)
          if user then flt()[key] = self:GetText(); UI.RequestRefresh() end
        end)
        g.sync[#g.sync + 1] = function() e:SetText(flt()[key] or "") end
      end
    elseif d.t == "check" then
      local c = Check(g.adv, d.label, function() return flt()[d.k] end,
        function(v) flt()[d.k] = v; UI.RequestRefresh() end, d.label, d.tip)
      c:SetSize(150, 22)
      c:SetPoint("TOPLEFT", cx, cy - 18)
      g.sync[#g.sync + 1] = function() c:Refresh() end
    end
    col = col + 1
    if col == 3 then col = 0; row = row + 1 end
  end
  g.SyncAll = function() for _, fn in ipairs(g.sync) do fn() end end
  return g
end

---------------------------------------------------------------- Settings
function UI.BuildSettings()
  local s = GF.db.settings
  local p = Modal("GuildFinderSettings", 700, 660, "Settings")
  local widgets = {}

  local function section(text, x, y)
    local fs = FS(p, text, "small", ACC); fs:SetPoint("TOPLEFT", x, y)
  end
  local function chk(label, key, x, y, desc, after)
    local c = Check(p, label, function() return s[key] end, function(v) s[key] = v; if after then after() end end, label, desc)
    c:SetPoint("TOPLEFT", x, y); widgets[#widgets + 1] = c
  end
  local function drop(label, key, opts, x, y, desc, after)
    local b = Dropdown(p, label, 300, function() return opts end, function() return s[key] end,
      function(v) s[key] = v; if after then after() end end, label, desc)
    b:SetPoint("TOPLEFT", x, y); widgets[#widgets + 1] = b
  end
  local function act(text, x, y, fn, tt, td, variant)
    Btn(p, text, 300, 26, fn, variant or "normal", tt, td):SetPoint("TOPLEFT", x, y)
  end

  section("SYNC", 24, -60)
  chk("Enable syncing", "syncEnabled", 24, -82, "Master switch for sharing listings through the private sync channel.")
  chk("Accept relayed listings", "acceptRelayed", 24, -108, "Accept listings passed on by other users (they cannot be verified).")
  chk("Auto-renew my adverts on login", "autoRenew", 24, -134, "Renews your active adverts every time you log in.")
  section("ALERTS AND DISPLAY", 24, -170)
  chk("Notify me about matching listings", "notify", 24, -192, "Prints one chat line (and pulses the minimap button) when matching listings arrive.")
  chk("Play a sound with notifications", "notifySound", 24, -218, "Plays a sound with the notification.")
  chk("Remind me before my advert expires", "expiryWarn", 24, -244, "Prints a reminder when one of your adverts has under 24 hours left.")
  chk("Compact list", "compact", 24, -270, "One line per listing.", UI.RequestRefresh)
  chk("Read guild posts from chat (unverified)", "scanChat", 24, -296,
    "Reads guild-recruitment lines from General / Trade chat and shows them as 'From chat' listings that are not shared with anyone. Off by default.", UI.RequestRefresh)
  p.autoNote = FS(p, "", "small", COL.dim)
  p.autoNote:SetPoint("TOPLEFT", 24, -328); p.autoNote:SetWidth(310); p.autoNote:SetJustifyH("LEFT")

  section("GENERAL", 360, -60)
  p.rsText = FS(p, "", "normal")
  p.rsText:SetPoint("TOPLEFT", 360, -88)
  drop("Advert expiry (days)", "expiryDays", { 1, 3, 7, 14, 30 }, 360, -114, "How long adverts stay visible before expiring.")
  drop("Max adverts per type", "maxAdverts", { 1, 2, 3, 5 }, 360, -146, "Maximum guild adverts and maximum player adverts per character.")
  drop("Window scale", "scale", { 0.7, 0.8, 0.9, 1, 1.1, 1.2 }, 360, -178, "Scales the Guild Finder window. Use a smaller value if it is too big for your screen.", function() if UI.frame then UI.frame:SetScale(s.scale) end end)
  section("TOOLS", 360, -218)
  act("Rejoin sync channel", 360, -240, function() Sync.JoinChannel(true); GF.Print("Trying to join " .. Sync.ChannelName() .. "...") end, "Rejoin", "Tries to join the private sync channel again.")
  act("Test sync channel", 360, -270, function()
    Sync.JoinChannel(true)
    GF.Print("Sync channel diagnostics:")
    C_Timer.After(2.5, function() for _, line in ipairs(Sync.Diag()) do print("  " .. line) end end)
  end, "Test sync", "Joins the channel and sends a test message. The result shows in chat.")
  act("Export adverts (text)", 360, -300, function() UI.TextBox("Export adverts", Data.Export(), nil, nil, "Press Ctrl+A, Ctrl+C to copy.") end, "Export", "Shows all listings as text you can share.")
  act("Import adverts (text)", 360, -330, function()
    UI.TextBox("Import adverts", "", "Import", function(text)
      local n, bad = Data.Import(text)
      GF.Print(("Imported %d listing(s), %d skipped."):format(n, bad))
      UI.Refresh()
    end, "Paste exported text, then click Import.")
  end, "Import", "Paste text from Export. Everything is validated.")
  act("Reset window position and size", 360, -360, function()
    GF.db.window = { v = LAYOUT_VERSION }
    UI.frame:ClearAllPoints(); UI.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    UI.frame:SetSize(UI.DefaultSize())
    UI.Layout(); UI.Refresh()
  end, "Reset window", "Moves the window back to the centre at its default size.")
  act("Clear cached listings", 360, -390, function() StaticPopup_Show("GUILDFINDER_CLEAR") end, "Clear cache", "Removes other players' listings. Yours are kept.", "danger")
  act("Clear hidden / blocked lists", 360, -420, function()
    GF.db.blocked.listings, GF.db.blocked.authors = {}, {}
    UI.Refresh(); GF.Print("Hidden and blocked lists cleared.")
  end, "Unblock all", "Shows previously hidden listings and authors again.")

  section("MESSAGE TEMPLATES", 24, -380)
  local rl = FS(p, "Short reason ([Short Reason])", "small", COL.dim); rl:SetPoint("TOPLEFT", 24, -402)
  local re = Edit(p, 300, 80); re:SetPoint("TOPLEFT", 24, -418)
  re:HookScript("OnTextChanged", function(self, user) if user then s.reason = self:GetText() end end)
  local al = FS(p, "Application (player to guild)", "small", COL.dim); al:SetPoint("TOPLEFT", 24, -454)
  local ae = MultiEdit(p, 310, 60, 600); ae:SetPoint("TOPLEFT", 24, -470)
  ae.edit:HookScript("OnTextChanged", function(self, user) if user then s.appTemplate = self:GetText() end end)
  local il = FS(p, "Invite (recruiter to player)", "small", COL.dim); il:SetPoint("TOPLEFT", 24, -540)
  local ie = MultiEdit(p, 310, 60, 600); ie:SetPoint("TOPLEFT", 24, -556)
  ie.edit:HookScript("OnTextChanged", function(self, user) if user then s.inviteTemplate = self:GetText() end end)
  local hint = FS(p, "Placeholders: [Guild Contact] [Guild Name] [Class] [Spec] [Role] [Level] [Guild Type] [Availability] [Short Reason] [Player Name] [Role/Class/Spec] [Focus] [Schedule] [Raid]", "small", COL.dim)
  hint:SetPoint("TOPLEFT", 360, -470); hint:SetWidth(310); hint:SetJustifyH("LEFT")
  local rt = Btn(p, "Reset templates", 150, 26, function()
    s.appTemplate, s.inviteTemplate = T.DEFAULT_APP, T.DEFAULT_INVITE
    ae.edit:SetText(s.appTemplate); ie.edit:SetText(s.inviteTemplate)
  end, "normal", "Reset templates", "Restores both default message templates.")
  rt:SetPoint("BOTTOMRIGHT", -20, 20)

  function p:Refresh()
    for _, w in ipairs(widgets) do w:Refresh() end
    self.rsText:SetText(("Your ruleset: |cff%s%s|r  |cff%s(automatic)|r"):format("33e680", RulesetName(), DIMHEX))
    self.autoNote:SetText("Faction (" .. (GF.myFaction or "?") .. ") and ruleset are detected automatically. You only see listings that match both.")
    re:SetText(s.reason or ""); ae.edit:SetText(s.appTemplate or ""); ie.edit:SetText(s.inviteTemplate or "")
    re:SetCursorPosition(0)
  end
  UI.settings = p
end

function UI.OpenSettings()
  if not UI.settings then UI.BuildSettings() end
  UI.settings:SetScale(math.min(1, (UIParent:GetHeight() - 30) / 660))
  UI.settings:Refresh()
  UI.settings:Show()
end

---------------------------------------------------------------- Status, navigation, layout
function UI.UpdateStatus()
  if not UI.statusText then return end
  local state, text, peers = Sync.Status()
  local c = ({ ok = { .2, .9, .4 }, idle = { .95, .8, .2 }, off = { .6, .6, .6 }, error = { .9, .3, .3 } })[state] or { .6, .6, .6 }
  UI.statusDot:SetColorTexture(c[1], c[2], c[3], 1)
  UI.statusText:SetText(tostring(text or state))
  local lu = GF.db.lastUpdate
  UI.statusSub:SetText(("%d cached | %s"):format(Data.Count(), lu and ("updated " .. Ago(lu) .. " ago") or "no updates yet"))
end

function UI.UpdateNav()
  for key, b in pairs(UI.nav) do b.active = (key == UI.page); b:Paint() end
end

function UI.SyncControls()
  local kind = UI.ListKind()
  UI.search:SetText(GF.filters[kind].search or "")
  UI.groups[kind].SyncAll()
end

function UI.Layout()
  local browse = UI.IsBrowse()
  local kind = UI.ListKind()
  UI.groups.G.quick:SetShown(browse and kind == "G"); UI.groups.P.quick:SetShown(browse and kind == "P")
  UI.groups.G.adv:SetShown(kind == "G"); UI.groups.P.adv:SetShown(kind == "P")
  UI.quickBar:SetShown(browse); UI.btnMore:SetShown(browse); UI.search:SetShown(browse)
  UI.createBtn:SetShown(not UI.IsSaved())
  UI.advPanel:Hide()
  UI.listScroll:ClearAllPoints()
  UI.listScroll:SetPoint("TOPLEFT", UI.frame, "TOPLEFT", 188, browse and -140 or -104)
  UI.listScroll:SetPoint("BOTTOMRIGHT", UI.frame, "BOTTOMRIGHT", -324, 14)
  UI.listScroll:Update()
  UI.groups[kind].LayoutQuick()
end

function UI.SetPage(page, selectId)
  UI.page = page
  UI.selected = selectId
  UI.UpdateNav(); UI.Layout(); UI.SyncControls(); UI.Refresh()
end

function UI.Toggle()
  if not UI.frame then return end
  if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end
end

-- Default window size: big enough for every control, but never larger than the screen.
function UI.DefaultSize()
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  local sc = (GF.db and GF.db.settings.scale) or 1
  sw, sh = sw / sc, sh / sc
  return math.max(1000, math.min(1240, sw - 40)), math.max(580, math.min(720, sh - 40))
end

---------------------------------------------------------------- Main window
function UI.Init()
  if UI.frame then return end
  local s = GF.db.settings
  local f = Box(UIParent, COL.bg, { .22, .25, .29, 1})
  f:SetParent(UIParent)
  _G.GuildFinderFrame = f
  UI.frame = f
  f:SetFrameStrata("HIGH")
  f:SetMovable(true); f:SetResizable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  if f.SetResizeBounds then f:SetResizeBounds(1000, 580, 1700, 1000) elseif f.SetMinResize then f:SetMinResize(1000, 580) end
  f:SetScale(s.scale or 1)
  local w = GF.db.window
  if w.v ~= LAYOUT_VERSION then -- layout changed: drop the old saved size once, keep the position
    w.w, w.h, w.v = nil, nil, LAYOUT_VERSION
  end
  local dw, dh = UI.DefaultSize()
  f:SetSize(w.w and math.max(1000, w.w) or dw, w.h and math.max(580, w.h) or dh)
  f:ClearAllPoints()
  f:SetPoint(w.p or "CENTER", UIParent, w.rp or "CENTER", w.x or 0, w.y or 20)
  tinsert(UISpecialFrames, "GuildFinderFrame")
  f:Hide()

  local function SavePos()
    local p, _, rp, x, y = f:GetPoint()
    GF.db.window = { p = p, rp = rp, x = x, y = y, w = f:GetWidth(), h = f:GetHeight(), v = LAYOUT_VERSION }
  end

  -- Header
  local header = CreateFrame("Frame", nil, f)
  header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(40)
  header:EnableMouse(true); header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() f:StartMoving() end)
  header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); SavePos() end)
  local hl = header:CreateTexture(nil, "BACKGROUND"); hl:SetAllPoints(); hl:SetColorTexture(COL.side[1], COL.side[2], COL.side[3], 1)
  local line = header:CreateTexture(nil, "ARTWORK"); line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetColorTexture(COL.border[1], COL.border[2], COL.border[3], 1)
  local bar = header:CreateTexture(nil, "OVERLAY"); bar:SetSize(4, 18); bar:SetPoint("LEFT", 14, 0)
  bar:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
  local title = FS(header, "Guild Finder", "large"); title:SetPoint("LEFT", bar, "RIGHT", 10, 0)
  local ver = FS(header, "WoW Forever  |  v" .. GF.VERSION, "small", COL.dim); ver:SetPoint("LEFT", title, "RIGHT", 12, -1)
  local close = Btn(header, "x", 26, 26, function() f:Hide() end, "normal"); close:SetPoint("RIGHT", -8, 0)
  UI.search = Edit(header, 260, 80, "Search listings...")
  UI.search:SetPoint("RIGHT", close, "LEFT", -12, 0)
  UI.search:HookScript("OnTextChanged", function(self, user)
    if user then GF.filters[UI.ListKind()].search = self:GetText(); UI.RequestRefresh() end
  end)
  Tip(UI.search, "Search", "Searches names, descriptions, class/spec, focus and more. Every word must match.")

  -- Sidebar
  local side = CreateFrame("Frame", nil, f)
  side:SetPoint("TOPLEFT", 0, -41); side:SetPoint("BOTTOMLEFT"); side:SetWidth(176)
  local sbg = side:CreateTexture(nil, "BACKGROUND"); sbg:SetAllPoints(); sbg:SetColorTexture(COL.side[1], COL.side[2], COL.side[3], 1)
  local sline = side:CreateTexture(nil, "ARTWORK"); sline:SetWidth(1)
  sline:SetPoint("TOPRIGHT"); sline:SetPoint("BOTTOMRIGHT"); sline:SetColorTexture(COL.border[1], COL.border[2], COL.border[3], 1)
  UI.nav = {}
  local function Section(text, y) local fs = FS(side, text, "small", COL.dim); fs:SetPoint("TOPLEFT", 16, y) end
  local function Nav(key, text, y, tt, td)
    local b = Btn(side, text, 176, 32, function() UI.SetPage(key) end, "nav", tt, td)
    b:SetPoint("TOPLEFT", 0, y)
    UI.nav[key] = b
  end
  Section("BROWSE", -14)
  Nav("guild", "Find a Guild", -30, "Find a Guild", "Browse guild adverts from your faction and ruleset. Apply by whisper.")
  Nav("members", "Find Members", -64, "Find Members", "Browse player adverts from your faction and ruleset. Invite by whisper.")
  Section("SAVED", -110)
  Nav("fav", "Favourites", -126, "Favourites", "Listings you starred. Private, only on your computer.")
  Nav("hist", "Contacted", -160, "Contacted", "Listings you have whispered, newest first.")
  Section("MY ADVERTS", -206)
  Nav("myP", "Looking for a guild", -222, "My player advert", "Post, edit or pause your own Looking-For-Guild advert.")
  Nav("myG", "My guild adverts", -256, "My guild adverts", "Post, edit or pause adverts for your guild.")

  UI.statusDot = side:CreateTexture(nil, "OVERLAY"); UI.statusDot:SetSize(8, 8); UI.statusDot:SetPoint("BOTTOMLEFT", 16, 112)
  UI.statusText = FS(side, "", "small"); UI.statusText:SetPoint("LEFT", UI.statusDot, "RIGHT", 6, 0)
  UI.statusText:SetPoint("RIGHT", side, "RIGHT", -8, 0); UI.statusText:SetJustifyH("LEFT"); UI.statusText:SetWordWrap(false)
  UI.statusSub = FS(side, "", "small", COL.dim); UI.statusSub:SetPoint("BOTTOMLEFT", 16, 94)
  UI.statusSub:SetPoint("RIGHT", side, "RIGHT", -8, 0); UI.statusSub:SetJustifyH("LEFT"); UI.statusSub:SetWordWrap(false)
  local sb = CreateFrame("Button", nil, side)
  sb:SetPoint("BOTTOMLEFT", 8, 88); sb:SetSize(160, 36)
  sb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Sync status", 1, 1, 1)
    local st = Sync.stats
    GameTooltip:AddLine("Guild Finder shares adverts through a private channel with other players who run the addon.", .8, .8, .8, true)
    GameTooltip:AddLine(("Sent %d | Received %d | Rejected %d | Queued %d"):format(st.sent, st.recv, st.rejected, #Sync.queue), nil, nil, nil, true)
    GameTooltip:AddLine("Channel: " .. Sync.ChannelName() .. (Sync.ChannelId() and "" or " (not joined)"), .7, .7, .7, true)
    if st.lastError then GameTooltip:AddLine("Last error: " .. tostring(st.lastError), 1, .3, .3, true) end
    GameTooltip:AddLine("Green: other users online. Yellow: connected but nobody seen yet. Red: error. Grey: off.", .6, .6, .6, true)
    GameTooltip:AddLine("An empty list is normal until other players on your faction and ruleset use the addon. Your own adverts always work.", .6, .6, .6, true)
    GameTooltip:Show()
  end)
  sb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local refresh = Btn(side, "Refresh listings", 160, 26, function()
    local ok, why = Sync.Request(true)
    GF.Print(ok and "Requested the latest listings from other users." or why)
    UI.Refresh()
  end, "normal", "Refresh listings", "Asks other Guild Finder users on the sync channel for their latest listings.")
  refresh:SetPoint("BOTTOMLEFT", 8, 50)
  local settingsBtn = Btn(side, "Settings", 160, 26, function() UI.OpenSettings() end, "normal", "Settings", "Sync, expiry, templates and display options.")
  settingsBtn:SetPoint("BOTTOMLEFT", 8, 16)

  -- Page header (title on the left, buttons on the right, never overlapping)
  UI.pageTitle = FS(f, "", "large"); UI.pageTitle:SetPoint("TOPLEFT", 188, -54)
  UI.pageSub = FS(f, "", "small", COL.dim); UI.pageSub:SetPoint("TOPLEFT", 188, -78)
  UI.createBtn = Btn(f, "+ Create", 230, 30, function() UI.OpenEditor(UI.CreateKind()) end, "accent",
    "Create an advert", "Find a Guild: post your own Looking-For-Guild advert. Find Members: post a guild advert.")
  UI.createBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -324, -54)
  UI.btnMore = Btn(f, "More filters", 110, 30, function()
    UI.advPanel:SetShown(not UI.advPanel:IsShown())
  end, "normal", "More filters", "Level stage, class, level, days, times, timezone, keywords, sorting, favourites.")
  UI.btnMore:SetPoint("RIGHT", UI.createBtn, "LEFT", -8, 0)

  -- Quick filter bar + advanced popover
  UI.quickBar = CreateFrame("Frame", nil, f)
  UI.quickBar:SetPoint("TOPLEFT", f, "TOPLEFT", 188, -104); UI.quickBar:SetHeight(28)
  UI.quickBar:SetPoint("RIGHT", f, "RIGHT", -324, 0)
  UI.advPanel = Box(f, COL.side, { .3, .34, .38, 1 })
  UI.advPanel:SetFrameLevel(f:GetFrameLevel() + 30)
  UI.advPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 188, -138); UI.advPanel:SetSize(512, 350)
  UI.advPanel:EnableMouse(true)
  local at = FS(UI.advPanel, "More filters", "normal"); at:SetPoint("TOPLEFT", 18, -16)
  local adone = Btn(UI.advPanel, "Done", 90, 26, function() UI.advPanel:Hide() end, "accent"); adone:SetPoint("BOTTOMRIGHT", -16, 14)
  local areset = Btn(UI.advPanel, "Reset all filters", 130, 26, function()
    local k = UI.ListKind(); ResetFilters(k); UI.SyncControls(); UI.RequestRefresh()
  end, "normal"); areset:SetPoint("BOTTOMRIGHT", -116, 14)
  UI.advPanel:Hide()
  UI.groups = { G = BuildFilters("G", UI.quickBar, UI.advPanel), P = BuildFilters("P", UI.quickBar, UI.advPanel) }

  -- List
  UI.listScroll = Scroll(f)
  UI.empty = FS(f, "", "normal", COL.dim)
  UI.empty:SetPoint("CENTER", UI.listScroll, "CENTER", 0, 0); UI.empty:SetWidth(360); UI.empty:SetJustifyH("CENTER")

  BuildDetails(f)

  -- Resize grip
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2); grip:SetFrameLevel(f:GetFrameLevel() + 40)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); SavePos(); UI.Layout(); UI.Refresh() end)

  f:SetScript("OnShow", function() UI.UpdateNav(); UI.Layout(); UI.SyncControls(); UI.Refresh() end)
  f:SetScript("OnHide", function() SavePos(); UI.advPanel:Hide() end)
  f:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + el
    if self.t > 5 then self.t = 0; UI.UpdateStatus() end
  end)

  UI.BuildEditor()

  if Settings and Settings.RegisterCanvasLayoutCategory then
    pcall(function()
      local panel = CreateFrame("Frame")
      panel.name = "Guild Finder"
      local b = Btn(panel, "Open Guild Finder settings", 200, 26, function() UI.OpenSettings() end, "accent")
      b:SetPoint("TOPLEFT", 16, -16)
      local cat = Settings.RegisterCanvasLayoutCategory(panel, "Guild Finder")
      Settings.RegisterAddOnCategory(cat)
    end)
  end
  GF.Debug("UI initialised")
end
