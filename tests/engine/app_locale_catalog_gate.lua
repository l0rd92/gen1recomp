-- Ratchet for built-in application localization catalogs.
--
-- AppLocale uses English source strings as keys.  That keeps call sites
-- readable and preserves the same source-as-key model already used by
-- Strings(), but it means an English wording change intentionally orphans the
-- old translation.  This gate makes that visible in CI: every AppLocale
-- literal used by src/ must exist in every registered catalog, every catalog
-- entry must still have a live source, and format directives must remain
-- compatible.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local AppLocale = require("src.core.AppLocale")
local Catalogs = require("src.locales.registry")

-- Native application sources are deliberately explicit call-site literals.
-- If a future feature needs composed/dynamic source keys, add a source marker
-- API first rather than teaching this gate to guess runtime strings.
local function harvest(body)
  local found = {}
  for source in body:gmatch('AppLocale%s*%(%s*"([^"]+)"') do
    found[source] = true
  end
  for source in body:gmatch("AppLocale%s*%(%s*'([^']+)'") do
    found[source] = true
  end
  for source in body:gmatch('AppLocale%.text%s*%(%s*"([^"]+)"') do
    found[source] = true
  end
  for source in body:gmatch("AppLocale%.text%s*%(%s*'([^']+)'") do
    found[source] = true
  end
  for source in body:gmatch('AppLocale%.source%s*%(%s*"([^"]+)"') do
    found[source] = true
  end
  for source in body:gmatch("AppLocale%.source%s*%(%s*'([^']+)'") do
    found[source] = true
  end
  for source, context in body:gmatch(
      'AppLocale%.context%s*%(%s*"([^"]+)"%s*,%s*"([^"]+)"') do
    found[context .. "|" .. source] = true
  end
  for source, context in body:gmatch(
      "AppLocale%.context%s*%(%s*'([^']+)'%s*,%s*'([^']+)'") do
    found[context .. "|" .. source] = true
  end
  for source in body:gmatch('AppMessage%s*%(%s*"([^"]+)"') do
    found[source] = true
  end
  for source in body:gmatch("AppMessage%s*%(%s*'([^']+)'") do
    found[source] = true
  end
  return found
end

-- High-confidence guard for application text passed straight to the drawing
-- kit.  Dynamic values are allowed, but a literal in the visible-text slot
-- must be wrapped in AppLocale even when its spelling is shared by both
-- languages.  Keeping this deliberately narrow avoids treating font names,
-- widget ids and mod-provided metadata as application copy.
local function bareUiSources(body)
  local found = {}
  for source in body:gmatch(
      'Kit%.text[%w]*%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"') do
    found[source] = true
  end
  for source in body:gmatch(
      "Kit%.text[%w]*%s*%(%s*'[^']+'%s*,%s*'([^']+)'") do
    found[source] = true
  end
  for source in body:gmatch(
      'Kit%.caption%s*%([^,]+,[^,]+,%s*"([^"]+)"') do
    found[source] = true
  end
  for source in body:gmatch(
      "Kit%.caption%s*%([^,]+,[^,]+,%s*'([^']+)'") do
    found[source] = true
  end
  return found
end

local used = {}
local bare = {}
local gameplayStringUses = {}
local scanned = 0
for _, path in ipairs(FsIo.luaFilesUnder("src")) do
  -- Do not harvest examples/comments in the implementation or catalogs; only
  -- application call sites define the live source inventory.
  if path ~= "src/core/AppLocale.lua" and path ~= "src/core/AppMessage.lua"
      and not path:match("^src/locales/") then
    local f = io.open(path, "rb")
    if f then
      local body = f:read("*a")
      f:close()
      scanned = scanned + 1
      for source in pairs(harvest(body)) do used[source] = true end
      if path:match("^src/import/") then
        for source in pairs(bareUiSources(body)) do
          bare[#bare + 1] = path .. ": " .. source
        end
        if body:match("Strings%s*%(")
            or body:match('require%s*%(%s*"src%.core%.Strings"')
            or body:match("require%s*%(%s*'src%.core%.Strings'") then
          gameplayStringUses[#gameplayStringUses + 1] = path
        end
      end
    end
  end
end

-- AppLocale normally contains implementation rather than call-site sources,
-- but it also owns the centralized game-version names. Harvest only its real
-- localization calls so those keys stay in the same inventory as UI calls.
do
  local file = io.open("src/core/AppLocale.lua", "rb")
  if file then
    local body = file:read("*a")
    file:close()
    for source in pairs(harvest(body)) do used[source] = true end
  end
end

T.check(scanned > 20, "the app-locale gate scanned the source tree")
T.check(next(used) ~= nil, "at least one native application source is harvested")
table.sort(gameplayStringUses)
T.check(#gameplayStringUses == 0,
  ("%d import/launcher module(s) still depend on gameplay Strings: %s")
    :format(#gameplayStringUses, table.concat(gameplayStringUses, ", ")))

local ids = {}
-- These are real on-disk paths and data-field names, not English prose.
-- Translating them makes otherwise helpful instructions point at folders or
-- JSON fields that do not exist.
local protectedLiterals = {
  "imports/", "baseroms/", "index.json", "schema_version", "SHA-1",
}
-- A translation may legitimately match the English source (international
-- abbreviations, loanwords, product labels).  Everything else must be an
-- explicit translation instead of a silently unfinished draft entry.
local allowedUnchanged = {
  ["es-ES"] = {
    ["DBI MTP → 1: SD Card/%simports/"] = true,
    ["DBI MTP → 1: SD Card/%simports/mods/"] = true,
    Incompatible = true, MODS = true, MOD = true, NORMAL = true,
  },
  ["fr-FR"] = {
    Portrait = true, Incompatible = true, MODS = true, MOD = true, OK = true,
    Source = true, Versions = true, AUTO = true, OPTIONS = true,
    ORIENTATION = true, PORTRAIT = true, VIBRATION = true,
  },
  ["de-DE"] = {
    Filter = true, MODS = true, MOD = true, Name = true, OK = true,
    AUTO = true, ["GBC FX"] = true, OG = true, ["OG INV"] = true,
    VIBRATION = true, NORMAL = true,
  },
  ["it-IT"] = {
    ["1 slot"] = true, MOD = true, OK = true, AUTO = true, OG = true,
    ["OG INV"] = true,
  },
  ["pt-BR"] = {
    ["%d slots"] = true, ["1 slot"] = true, MODS = true, MOD = true,
    OK = true, AUTO = true, ["GBC FX"] = true, OG = true, NORMAL = true,
  },
}

-- A duplicate Lua table key silently replaces the earlier translation before
-- the runtime or the checks below can see it. Catch duplicates in source so a
-- catalog edit cannot pass CI while hiding one of the translator's entries.
local duplicateKeys = {}
for _, path in ipairs(FsIo.luaFilesUnder("src/locales")) do
  if path ~= "src/locales/registry.lua" then
    local seen = {}
    local file = io.open(path, "rb")
    if file then
      local body = file:read("*a")
      file:close()
      local lineNumber = 0
      for line in (body .. "\n"):gmatch("(.-)\n") do
        lineNumber = lineNumber + 1
        local key = line:match('^%s*%["(.-)"%]%s*=')
        if key then
          if seen[key] then
            duplicateKeys[#duplicateKeys + 1] =
              ("%s:%d duplicates line %d: %s")
                :format(path, lineNumber, seen[key], key)
          else
            seen[key] = lineNumber
          end
        end
      end
    end
  end
end
table.sort(duplicateKeys)
T.check(#duplicateKeys == 0,
  ("%d duplicate application catalog key(s): %s")
    :format(#duplicateKeys, table.concat(duplicateKeys, ", ")))

for _, catalog in ipairs(Catalogs) do
  local id = tostring(catalog.id)
  T.check(not ids[id], "registered locale ids are unique: " .. id)
  ids[id] = true
  T.check(type(catalog.name) == "string" and catalog.name ~= "",
    id .. " has a self-identifying display name")
  T.check(catalog.reviewStatus == "native-reviewed"
      or catalog.reviewStatus == "pending-native-review",
    id .. " declares its linguistic review status")
  T.check(type(catalog.strings) == "table", id .. " has a strings table")

  local missing, stale, badFormat, changedLiterals, untranslated = {}, {}, {}, {}, {}
  local staleAllowances = {}
  local allowed = allowedUnchanged[id] or {}
  for source in pairs(used) do
    local translated = catalog.strings[source]
    if type(translated) ~= "string" or translated == "" then
      missing[#missing + 1] = source
    elseif not AppLocale.formatCompatible(source, translated) then
      badFormat[#badFormat + 1] = source
    else
      if source == translated and not allowed[source] then
        untranslated[#untranslated + 1] = source
      end
      for _, literal in ipairs(protectedLiterals) do
        if source:find(literal, 1, true)
            and not translated:find(literal, 1, true) then
          changedLiterals[#changedLiterals + 1] = source .. " [" .. literal .. "]"
        end
      end
    end
  end
  for source, translated in pairs(catalog.strings) do
    if type(source) ~= "string" or type(translated) ~= "string" then
      stale[#stale + 1] = tostring(source) .. " (malformed entry)"
    elseif not used[source] then
      stale[#stale + 1] = source
    end
  end
  for source in pairs(allowed) do
    if catalog.strings[source] ~= source then
      staleAllowances[#staleAllowances + 1] = source
    end
  end

  table.sort(missing)
  table.sort(stale)
  table.sort(badFormat)
  table.sort(changedLiterals)
  table.sort(untranslated)
  table.sort(staleAllowances)

  T.check(#missing == 0,
    ("%d application source(s) missing from %s: %s")
      :format(#missing, id, table.concat(missing, ", ")))
  T.check(#stale == 0,
    ("%d stale %s source key(s): %s")
      :format(#stale, id, table.concat(stale, ", ")))
  T.check(#badFormat == 0,
    ("%d %s translation(s) have incompatible format directives: %s")
      :format(#badFormat, id, table.concat(badFormat, ", ")))
  T.check(#changedLiterals == 0,
    ("%d %s translation(s) changed a protected path or field: %s")
      :format(#changedLiterals, id, table.concat(changedLiterals, ", ")))
  T.check(#untranslated == 0,
    ("%d %s source(s) remain in English without an explicit exception: %s")
      :format(#untranslated, id, table.concat(untranslated, ", ")))
  T.check(#staleAllowances == 0,
    ("%d stale %s unchanged-source exception(s): %s")
      :format(#staleAllowances, id, table.concat(staleAllowances, ", ")))
end

table.sort(bare)
T.check(#bare == 0,
  ("%d bare application UI literal(s): %s")
    :format(#bare, table.concat(bare, ", ")))

T.finish("app_locale_catalog_gate")
