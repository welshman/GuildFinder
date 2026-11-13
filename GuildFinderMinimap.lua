local ADDON, GF = ...
local M = {}
GF.Minimap = M

local ICON = "Interface\\AddOns\\GuildFinder\\GuildFinderIcon"
local button

local function UpdatePosition()
  if not button then return end
  local angle = math.rad(GF.db.minimap.angle or 215)
  local x, y = math.cos(angle), math.sin(angle)
  local w, h = Minimap:GetWidth() / 2 + 5, Minimap:GetHeight() / 2 + 5
  if GetMinimapShape and GetMinimapShape() == "SQUARE" then
    x = math.max(-1, math.min(1, x * 1.4142))
    y = math.max(-1, math.min(1, y * 1.4142))
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
end

local function OnDragUpdate()
  local mx, my = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = Minimap:GetCenter()
  if not cx then return end
  local atan = math.atan2 or math.atan
  GF.db.minimap.angle = math.deg(atan(my / scale - cy, mx / scale - cx))
  UpdatePosition()
end

function M.UpdateStatus()
  if not button or not GF.Sync or not GF.Sync.Status then return end
  local ok, state = pcall(GF.Sync.Status)
  local c = ({ ok = { .2, .9, .3 }, idle = { .95, .8, .2 }, off = { .6, .6, .6 }, error = { .9, .25, .25 } })[ok and state or "off"] or { .6, .6, .6 }
  button.dot:SetColorTexture(c[1], c[2], c[3], 1)
end

function M.SetShown(show)
  GF.db.minimap.hide = not show
  if button then button:SetShown(show) end
end

function M.Create()
  if button then return end
  GF.db.minimap = GF.db.minimap or {}
  if GF.db.minimap.angle == nil then GF.db.minimap.angle = 215 end

  button = CreateFrame("Button", "GuildFinderMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20); bg:SetPoint("TOPLEFT", 7, -5)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(19, 19); icon:SetPoint("TOPLEFT", 6, -5)
  icon:SetTexture(ICON)
  icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local dot = button:CreateTexture(nil, "OVERLAY", nil, 2)
  dot:SetSize(7, 7); dot:SetPoint("BOTTOMRIGHT", -4, 5)
  dot:SetColorTexture(.6, .6, .6, 1)
  button.dot = dot

  button:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
      if GF.UI and GF.UI.OpenSettings then GF.UI.OpenSettings() end
    else
      if GF.UI and GF.UI.Toggle then GF.UI.Toggle() end
    end
  end)
  button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil); UpdatePosition() end)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Guild Finder", 1, 1, 1)
    local ok, state, text, peers = pcall(GF.Sync.Status)
    if ok then
      GameTooltip:AddLine(tostring(text or state), .8, .8, .8)
    end
    GameTooltip:AddLine(("%d listings cached"):format(GF.Data and GF.Data.Count() or 0), .8, .8, .8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open Guild Finder", .6, 1, .6)
    GameTooltip:AddLine("Right-click: settings", .6, 1, .6)
    GameTooltip:AddLine("Drag: move around the minimap", .6, 1, .6)
    GameTooltip:Show()
    M.UpdateStatus()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  UpdatePosition()
  button:SetShown(not GF.db.minimap.hide)
  M.UpdateStatus()
  C_Timer.NewTicker(10, M.UpdateStatus)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ok, err = pcall(M.Create)
  if not ok then print("|cffff4040Guild Finder minimap error|r: " .. tostring(err)) end
end)

-- /gfmap = show/hide the button, /gfmap reset = put it back at the default spot
SLASH_GUILDFINDERMAP1 = "/gfmap"
SlashCmdList["GUILDFINDERMAP"] = function(msg)
  if not GF.db or not button then return end
  msg = strtrim(msg or ""):lower()
  if msg == "reset" then
    GF.db.minimap.angle = 215
    UpdatePosition()
    GF.Print("Minimap button position reset.")
  else
    M.SetShown(GF.db.minimap.hide and true or false)
    GF.Print("Minimap button " .. (GF.db.minimap.hide and "hidden. Type /gfmap to show it again." or "shown."))
  end
end
