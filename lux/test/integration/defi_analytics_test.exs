defmodule Lux.Integration.DefiAnalyticsTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.DefiLlama.GetProtocols
  alias Lux.Lenses.DefiLlama.GetTvl
  alias Lux.Lenses.DefiLlama.GetYields
  alias Lux.Prisms.Defi.AnalyticsDashboardPrism

  # Since DefiLlama is a public API, we can safely run these in integration tests
  # Dune Analytics requires a key, so we won't execute it unless configured
  
  test "GetTvl fetches historical TVL" do
    assert {:ok, data} = GetTvl.focus(%{})
    assert is_list(data)
    assert length(data) > 0
    assert %{"date" => _, "tvl" => _} = List.first(data)
  end

  test "GetProtocols fetches list of protocols" do
    assert {:ok, data} = GetProtocols.focus(%{})
    assert is_list(data)
    assert length(data) > 0
    assert %{"name" => _, "slug" => _, "tvl" => _} = List.first(data)
  end

  test "GetYields fetches pool data" do
    assert {:ok, data} = GetYields.focus(%{})
    assert is_list(data)
    assert length(data) > 0
    assert %{"pool" => _, "apy" => _, "tvlUsd" => _} = List.first(data)
  end

  test "AnalyticsDashboardPrism runs successfully for a known protocol" do
    # Assuming 'aave' exists, which is extremely likely for DefiLlama
    assert {:ok, result} = AnalyticsDashboardPrism.run(%{protocol_slug: "aave"})
    assert %{protocol: protocol, pools: pools, custom_analytics: nil} = result
    assert protocol["slug"] == "aave"
    assert is_list(pools)
  end
end
