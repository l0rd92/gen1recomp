-- The touch-controls editor is launcher-owned application UI even though it
-- temporarily replaces the launcher screen.  It must follow Interface
-- Language without translating the physical A/B/START/SELECT button names.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")

local T = require("tests.harness")
local check = T.check
local AppLocale = require("src.core.AppLocale")
local SaveData = require("src.core.SaveData")
local TouchControls = require("src.core.TouchControls")

local oldLoad, oldSave = SaveData.loadOptions, SaveData.saveOptions
SaveData.loadOptions = function()
  return { interfaceLocale = "es-ES", touchControls = { enabled = true } }
end
SaveData.saveOptions = function() end

AppLocale.set("es-ES")
package.loaded["src.ui.TouchControlsEditor"] = nil
local Editor = require("src.ui.TouchControlsEditor")
Editor.load()

local seen = {}
local realPrint, realPrintf = love.graphics.print, love.graphics.printf
love.graphics.print = function(text, ...)
  seen[#seen + 1] = tostring(text)
  return realPrint(text, ...)
end
love.graphics.printf = function(text, ...)
  seen[#seen + 1] = tostring(text)
  return realPrintf(text, ...)
end
local ok, err = pcall(Editor.draw)
love.graphics.print, love.graphics.printf = realPrint, realPrintf
Editor.unload()
SaveData.loadOptions, SaveData.saveOptions = oldLoad, oldSave

check(ok, "the localized touch editor draws: " .. tostring(err))
local text = table.concat(seen, "\n")
for _, expected in ipairs({
  "Controles táctiles",
  "Restablecer",
  "Listo",
  "Controles en pantalla",
  "SÍ",
  "Desactivar",
  "Tamaño de los botones (Horizontal)",
  "Arrastra cada botón para moverlo",
}) do
  check(text:find(expected, 1, true) ~= nil,
    "touch editor prints localized text: " .. expected)
end
check(text:find("Touch Controls", 1, true) == nil,
  "touch editor does not leak its English title in Spanish")
check(text:find("On-screen controls", 1, true) == nil,
  "touch editor does not leak its English toggle label in Spanish")

-- Every registered locale must keep the editor chrome readable at the
-- smallest supported desktop window as well as the normal launcher size.
-- Capture the actual print rectangles rather than assuming Latin glyph widths.
local oldDimensions = love.graphics.getDimensions
local oldPixelDimensions = love.graphics.getPixelDimensions
local function overlaps(a, b)
  return a and b and a.x < b.x + b.w and b.x < a.x + a.w
    and a.y < b.y + b.h and b.y < a.y + a.h
end
local function inside(inner, outer)
  return inner and outer and inner.x >= outer.x - 0.5
    and inner.y >= outer.y - 0.5
    and inner.x + inner.w <= outer.x + outer.w + 0.5
    and inner.y + inner.h <= outer.y + outer.h + 0.5
end

for _, locale in ipairs(AppLocale.available()) do
  AppLocale.set(locale.id)
  for _, size in ipairs({
    { 360, 480 }, { 480, 360 }, { 640, 480 }, { 1024, 768 },
  }) do
    local width, height = size[1], size[2]
    love.graphics.getDimensions = function() return width, height end
    love.graphics.getPixelDimensions = love.graphics.getDimensions
    Editor.load()

    local prints = {}
    local drawPrint = love.graphics.print
    love.graphics.print = function(value, x, y, ...)
      local font = love.graphics.getFont()
      prints[#prints + 1] = {
        text = tostring(value), x = x, y = y,
        w = font:getWidth(value), h = font:getHeight(),
      }
      return drawPrint(value, x, y, ...)
    end
    local drew, drawErr = pcall(Editor.draw)
    love.graphics.print = drawPrint

    local tag = ("%s at %dx%d"):format(locale.id, width, height)
    check(drew, tag .. " draws: " .. tostring(drawErr))
    if drew then
      local byText = {}
      for _, item in ipairs(prints) do byText[item.text] = item end
      local title = byText[AppLocale("Touch Controls")]
      local reset = Editor.rects.reset
      local done = Editor.rects.done
      local toggle = Editor.rects.toggle
      local sizeDown = Editor.rects.sizeDown
      check(inside(reset, { x = 0, y = 0, w = width, h = height })
          and inside(done, { x = 0, y = 0, w = width, h = height }),
        tag .. " keeps header actions inside the window")
      check(not overlaps(reset, done), tag .. " keeps header actions separate")
      check(title and not overlaps(title, reset) and not overlaps(title, done),
        tag .. " keeps the title clear of header actions")
      check(inside(byText[AppLocale("Reset")], reset)
          and inside(byText[AppLocale("Done")], done),
        tag .. " keeps complete header labels inside their buttons")
      check(inside(byText[AppLocale("Disable")], toggle),
        tag .. " keeps the complete toggle action inside its button")
      local toggleText = byText[AppLocale("On-screen controls")]
      check(toggleText and not overlaps(toggleText, toggle),
        tag .. " keeps the toggle clear of its label")
      local orient = TouchControls.orientation == "landscape"
        and AppLocale("Landscape") or AppLocale("Portrait")
      local sizeText = byText[AppLocale("Button size (%s)", orient)]
      check(sizeText and not overlaps(sizeText, sizeDown),
        tag .. " keeps size controls clear of their label")
    end
    Editor.unload()
  end
end

love.graphics.getDimensions = oldDimensions
love.graphics.getPixelDimensions = oldPixelDimensions

AppLocale.set("en")
T.finish("touch_controls_locale")
