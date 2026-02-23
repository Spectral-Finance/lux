defmodule Lux.Lenses.DeFiAnalytics.DuneAnalyticsLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.DeFiAnalytics.DuneAnalyticsLens

  describe "focus/2 — input validation" do
    test "rejects missing query_id" do
      result = DuneAnalyticsLens.focus(%{}, %{})
      assert {:error, _} = result
    end

    test "rejects when DUNE_API_KEY not configured" do
      System.delete_env("DUNE_API_KEY")
      result = DuneAnalyticsLens.focus(%{query_id: 1234567}, %{})
      assert {:error, "Missing configuration: DUNE_API_KEY"} = result
    end
  end

  describe "focus/2 — with API key configured" do
    setup do
      System.put_env("DUNE_API_KEY", "test_key_placeholder")
      on_exit(fn -> System.delete_env("DUNE_API_KEY") end)
      :ok
    end

    test "proceeds past config check with query_id" do
      result = DuneAnalyticsLens.focus(%{query_id: 1527369}, %{})
      assert {:error, reason} = result
      refute reason =~ "Missing configuration"
    end

    test "accepts max_rows parameter" do
      result = DuneAnalyticsLens.focus(%{
        query_id: 1527369,
        max_rows: 10
      }, %{})
      assert {:error, _} = result
    end

    test "accepts execute_fresh: false (default)" do
      result = DuneAnalyticsLens.focus(%{
        query_id: 1527369,
        execute_fresh: false
      }, %{})
      assert {:error, _} = result
    end

    test "accepts execute_fresh: true" do
      result = DuneAnalyticsLens.focus(%{
        query_id: 1527369,
        execute_fresh: true
      }, %{})
      assert {:error, _} = result
    end

    test "accepts query_parameters map" do
      result = DuneAnalyticsLens.focus(%{
        query_id: 1527369,
        query_parameters: %{"chain" => "ethereum", "days" => 7}
      }, %{})
      assert {:error, _} = result
    end
  end

  describe "schema" do
    test "schema has required query_id" do
      schema = DuneAnalyticsLens.view().schema
      assert Map.has_key?(schema.properties, :query_id)
      assert Map.has_key?(schema.properties, :max_rows)
      assert Map.has_key?(schema.properties, :execute_fresh)
      assert Map.has_key?(schema.properties, :query_parameters)
      assert "query_id" in (schema[:required] || [])
    end
  end
end
