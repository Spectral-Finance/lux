defmodule Lux.YouTube.ContentCreation.LocalizationEngineTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentCreation.LocalizationEngine

  describe "localize_package/3" do
    test "translates metadata across target locales" do
      title = "Production Agent Architecture"
      desc = "Complete step by step guide"
      locales = ["es", "de", "ja", "vi"]

      results = LocalizationEngine.localize_package(title, desc, locales)

      assert length(results) == 4
      loc_map = Map.new(results, fn r -> {r.locale, r} end)

      assert Map.has_key?(loc_map, "es")
      assert Map.has_key?(loc_map, "de")
      assert Map.has_key?(loc_map, "ja")
      assert Map.has_key?(loc_map, "vi")

      es_entry = Map.get(loc_map, "es")
      assert String.contains?(es_entry.title, "Cómo construir")
      assert length(es_entry.keywords) > 0
    end
  end
end
