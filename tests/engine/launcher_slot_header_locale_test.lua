-- Localized save-slot header reflow.  This is application chrome and needs no
-- ROM: long fixture strings stand in for a future locale without registering
-- or shipping another language.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check
love = require("tests.love_stub")

love.graphics.setLineJoin = love.graphics.setLineJoin or function() end
love.graphics.newShader = love.graphics.newShader or function() return {} end

local AppLocale = require("src.core.AppLocale")
local Strings = require("src.core.Strings")
local Spanish = require("src.locales.es_es")
local Kit = require("src.ui.kit.Kit")
local RomImporter = require("src.import.RomImporter")
local LauncherView = require("src.import.LauncherView")

local windowW, windowH = 1280, 720
love.graphics.getDimensions = function() return windowW, windowH end
love.graphics.getPixelDimensions = love.graphics.getDimensions

local function freshLauncher(slot)
  local imp = RomImporter.new(function() end, { launcher = true })
  imp.tab = "red"
  imp._ensureSlots = function() end
  imp.slots.red = { slot or {
    id = "slot-a", label = "SLOT A", exists = false,
  } }
  imp.activeSlot.red = "slot-a"
  return imp
end

local function inside(rect, card)
  return rect.x >= card.x - 0.5 and rect.y >= card.y - 0.5
    and rect.x + rect.w <= card.x + card.w + 0.5
    and rect.y + rect.h <= card.y + card.h + 0.5
end

local function normalized(text)
  return tostring(text or ""):gsub("%s+", "")
end

local function capture(title, action, width, height, slot)
  windowW, windowH = width or 1280, height or 720
  local imp = freshLauncher(slot)
  LauncherView.draw(imp) -- warm frame: fonts, pagination and caches settle

  local cards, captions, actionLines, textLines = {}, {}, {}, {}
  local realCard, realCaption = Kit.card, Kit.caption
  local realButton, realText = Kit.button, Kit.text
  local realCenterBold = Kit.textCenterBold
  local capturingAction = false
  Kit.card = function(x, y, w, h, emphasis)
    cards[#cards + 1] = { x = x, y = y, w = w, h = h }
    return realCard(x, y, w, h, emphasis)
  end
  Kit.caption = function(x, y, label, color)
    captions[#captions + 1] = {
      x = x, y = y, w = Kit.captionWidth(label),
      h = Kit.textHeight("caption"), label = tostring(label),
    }
    return realCaption(x, y, label, color)
  end
  Kit.button = function(x, y, w, h, label, opts)
    local previous = capturingAction
    capturingAction = tostring(label) == action
    local result = realButton(x, y, w, h, label, opts)
    capturingAction = previous
    return result
  end
  Kit.text = function(name, label, ...)
    textLines[#textLines + 1] = tostring(label)
    return realText(name, label, ...)
  end
  Kit.textCenterBold = function(name, label, x, y, w, color, alpha)
    if capturingAction then
      actionLines[#actionLines + 1] = {
        label = tostring(label),
        width = Kit.textWidth(name, label),
      }
    end
    return realCenterBold(name, label, x, y, w, color, alpha)
  end
  Kit.audit = {}
  local ok, err = pcall(LauncherView.draw, imp)
  local audit = Kit.audit
  Kit.audit = nil
  Kit.card, Kit.caption, Kit.button = realCard, realCaption, realButton
  Kit.text = realText
  Kit.textCenterBold = realCenterBold
  check(ok, "localized slot-card frame draws: " .. tostring(err))
  if not ok then return {} end

  local found = { cards = cards, text = table.concat(textLines, "\n") }
  for _, rect in ipairs(audit) do
    if rect.class == "control" and rect.label == action then
      found.button = rect
    elseif rect.class == "row" and rect.label == "slot-red-slot-a" then
      found.row = rect
    end
  end
  local wanted = normalized(title)
  for first = 1, #captions do
    local combined = ""
    for last = first, #captions do
      combined = combined .. normalized(captions[last].label)
      if combined == wanted then
        local x1, y1 = math.huge, math.huge
        local x2, y2 = -math.huge, -math.huge
        found.titleLines = {}
        for i = first, last do
          local rect = captions[i]
          found.titleLines[#found.titleLines + 1] = rect
          x1, y1 = math.min(x1, rect.x), math.min(y1, rect.y)
          x2, y2 = math.max(x2, rect.x + rect.w), math.max(y2, rect.y + rect.h)
        end
        found.title = { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
        break
      end
      if #combined > #wanted then break end
    end
    if found.title then break end
  end
  found.actionLines = actionLines
  local drawn = {}
  for _, line in ipairs(actionLines) do drawn[#drawn + 1] = line.label end
  found.fullActionDrawn = normalized(table.concat(drawn)) == normalized(action)
  if found.button and found.row then
    for _, card in ipairs(cards) do
      if inside(found.button, card) and inside(found.row, card) then
        if not found.card or card.w * card.h < found.card.w * found.card.h then
          found.card = card
        end
      end
    end
  end
  return found
end

-- Save metadata belongs to the launcher, not to gameplay Strings. A
-- translation mod must not alter it when Interface Language is English, and
-- its override must not leak into a localized launcher.
Strings.load({ strings = {
  ["%d badges - %s - %d caught"] = "GAMEPLAY CATALOG LEAK %d %s %d",
} })
AppLocale.set("es-ES")
local metadata = capture(AppLocale("SAVE SLOT"), AppLocale("Import save"),
  1920, 1080, {
    id = "slot-b", label = "SLOT B", exists = true,
    meta = { badges = 3, timeText = "1:23", dexCount = 4 },
  })
check(metadata.text:find("Medallas: 3 - 1:23", 1, true) ~= nil,
  "save metadata follows Interface Language")
check(metadata.text:find("GAMEPLAY CATALOG LEAK", 1, true) == nil,
  "gameplay translation catalogs cannot alter launcher save metadata")

AppLocale.set("en")
local englishMetadata = capture("SAVE SLOT", "Import save", 1920, 1080, {
  id = "slot-b", label = "SLOT B", exists = true,
  meta = { badges = 3, timeText = "1:23", dexCount = 4 },
})
check(englishMetadata.text:find("3 badges - 1:23", 1, true) ~= nil,
  "English launcher metadata remains English")
check(englishMetadata.text:find("GAMEPLAY CATALOG LEAK", 1, true) == nil,
  "a gameplay catalog cannot alter English launcher metadata")
Strings.load({})

local function requireRects(frame, label)
  check(frame.title ~= nil, label .. ": full title is drawn")
  check(frame.button ~= nil, label .. ": import button is drawn")
  check(frame.row ~= nil, label .. ": slot row is drawn")
  check(frame.card ~= nil, label .. ": button and row remain in the slot card")
  return frame.title and frame.button and frame.row and frame.card
end

-- Actual catalogs must stay inside the save card in both the smallest
-- two-column layout and a narrow single-column layout. Long synthetic strings
-- below still cover the fallback path beyond today's languages.
for _, locale in ipairs(AppLocale.available()) do
  AppLocale.set(locale.id)
  for _, size in ipairs({ { 640, 720 }, { 480, 720 } }) do
    local title = AppLocale("SAVE SLOT")
    local action = AppLocale("Import save")
    local frame = capture(title, action, size[1], size[2])
    local label = ("%s at %dx%d"):format(locale.id, size[1], size[2])
    if requireRects(frame, label) then
      check(frame.fullActionDrawn == true,
        label .. ": import action is drawn in full")
      check(not (frame.title.x < frame.button.x + frame.button.w
          and frame.button.x < frame.title.x + frame.title.w
          and frame.title.y < frame.button.y + frame.button.h
          and frame.button.y < frame.title.y + frame.title.h),
        label .. ": title and import action do not overlap")
      check(frame.row.y >= frame.button.y + frame.button.h,
        label .. ": slot rows stay below the localized header")
    end
  end
end

-- Current English stays on the exact compact shape: title and button share
-- the header row, and the list starts below both.
AppLocale.set("en")
local compact = capture("SAVE SLOT", "Import save", 1280, 720)
if requireRects(compact, "compact source header") then
  check(compact.title.y < compact.button.y + compact.button.h
      and compact.button.y < compact.title.y + compact.title.h,
    "current short strings keep the one-line header")
  check(compact.row.y >= compact.button.y + compact.button.h,
    "compact header height keeps the slot list below it")
end

-- Inject deliberately long translations into the already registered Spanish
-- catalog for this process only.  Their combined width exceeds the card, but
-- each string fits by itself: this is the future-locale overlap regression.
local oldTitle = Spanish.strings["SAVE SLOT"]
local oldAction = Spanish.strings["Import save"]
local longTitle = "ADMINISTRACIÓN DE PARTIDAS GUARDADAS"
local longAction = "IMPORTAR UNA PARTIDA GUARDADA DESDE UN ARCHIVO"
Spanish.strings["SAVE SLOT"] = longTitle
Spanish.strings["Import save"] = longAction
AppLocale.set("es-ES")

local stacked = capture(longTitle, longAction)
if requireRects(stacked, "long localized header") then
  local pad = stacked.title.x - stacked.card.x
  local innerW = stacked.card.w - 2 * pad
  check(stacked.title.w <= innerW and stacked.button.w <= innerW,
    "each full localized string fits on its own row")
  check(stacked.title.w + stacked.button.w > innerW,
    "fixture genuinely cannot fit title and button on one row")
  check(stacked.button.y >= stacked.title.y + stacked.title.h,
    "long localized action moves below the complete title")
  check(stacked.row.y >= stacked.button.y + stacked.button.h,
    "two-line headH moves the slot list below the import button")
  check(stacked.button.x >= stacked.card.x + pad - 0.5
      and stacked.button.x + stacked.button.w
        <= stacked.card.x + stacked.card.w - pad + 0.5,
    "localized import button stays inside the card")
  check(Kit.textWidth("small", longAction)
      <= stacked.button.w - 16 * Kit.scale,
    "localized import action is not shortened to fit")
end

-- If the action is wider than a whole row, its control is clamped to the
-- card's inner width and uses Kit.button's wrapped-label path instead of
-- escaping the window or requesting an ellipsis.
local hugeAction = "IMPORTAR UNA PARTIDA GUARDADA DESDE UN ARCHIVO EXTERNO "
  .. "DEMASIADO LARGO PARA CABER EN UNA SOLA LÍNEA DE LA TARJETA"
Spanish.strings["Import save"] = hugeAction
local wrapped = capture(longTitle, hugeAction)
if requireRects(wrapped, "oversized localized action") then
  local pad = wrapped.title.x - wrapped.card.x
  local innerW = wrapped.card.w - 2 * pad
  check(Kit.textWidth("small", hugeAction) + math.floor(28 * Kit.scale) > innerW,
    "oversized fixture genuinely exceeds a whole header row")
  check(wrapped.button.w <= innerW + 0.5,
    "oversized import button is bounded by the card interior")
  check(wrapped.button.x >= wrapped.card.x + pad - 0.5
      and wrapped.button.x + wrapped.button.w
        <= wrapped.card.x + wrapped.card.w - pad + 0.5,
    "wrapped import button never leaves the card")
  check(wrapped.row.y >= wrapped.button.y + wrapped.button.h,
    "wrapped button height remains part of headH")
  check(wrapped.fullActionDrawn == true,
    "wrapped import action is drawn in full rather than ellipsized")
  for _, line in ipairs(wrapped.actionLines) do
    check(line.width <= wrapped.button.w - 16 * Kit.scale + 0.5,
      "every wrapped action line fits inside the button")
  end
end

-- Whitespace is not guaranteed in every script or compound word.  Exercise
-- a future locale whose title and action are each one uninterrupted token so
-- both wrapping paths must split safely at UTF-8 character boundaries.
local solidTitle = "SPEICHERSTANDVERWALTUNGSUEBERSICHTARCHIVDATEIAUSWAHL"
local solidAction = "SPEICHERSTANDARCHIVDATEIAUSWAHLBETAETIGUNG"
  .. "WIEDERHERSTELLUNGSBESTAETIGUNG"
Spanish.strings["SAVE SLOT"] = solidTitle
Spanish.strings["Import save"] = solidAction
local solid = capture(solidTitle, solidAction, 480, 720)
if requireRects(solid, "unbroken localized header") then
  check(#(solid.titleLines or {}) > 1,
    "an overwide unbroken title is split across lines")
  check(#(solid.actionLines or {}) > 1,
    "an overwide unbroken action is split across lines")
  check(solid.fullActionDrawn == true,
    "the unbroken action is drawn in full")
  check(solid.row.y >= solid.button.y + solid.button.h,
    "unbroken wrapped labels keep the list below the header")
  local pad = solid.title.x - solid.card.x
  local innerW = solid.card.w - 2 * pad
  for _, line in ipairs(solid.titleLines or {}) do
    check(line.w <= innerW + 0.5,
      "every unbroken title line fits inside the card")
  end
  for _, line in ipairs(solid.actionLines or {}) do
    check(line.width <= solid.button.w - 16 * Kit.scale + 0.5,
      "every unbroken action line fits inside the button")
  end
end

Spanish.strings["SAVE SLOT"] = oldTitle
Spanish.strings["Import save"] = oldAction
AppLocale.set("en")

T.finish("launcher_slot_header_locale")
