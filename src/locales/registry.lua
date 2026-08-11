-- Ordered application-interface locale catalogs.
--
-- English is the source/fallback locale and is created by AppLocale itself.
-- Add each translated catalog here once so the settings list, runtime lookup,
-- and catalog validation all use the same registry.
return {
  require("src.locales.es_es"),
  require("src.locales.fr_fr"),
  require("src.locales.de_de"),
  require("src.locales.it_it"),
  require("src.locales.pt_br"),
}
