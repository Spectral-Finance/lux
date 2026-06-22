defmodule Lux.Prisms.Defi.AnalyticsDashboardPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Defi.AnalyticsDashboardPrism
  import Mox

  # In a real test, we might want to mock the HTTP calls or use VCR.
  # For now, since DeFiLlama is public, we can test it directly or skip if we want to avoid network calls.
  @tag :integration
  test "dashboard prism aggregates data successfully" do
    input = %{"protocol_slug" => "uniswap"}
    
    assert {:ok, result} = AnalyticsDashboardPrism.handler(input, %{})
    
    assert Map.has_key?(result, :protocol)
    assert Map.has_key?(result, :pools)
    assert Map.has_key?(result, :custom_analytics)
    
    assert result.protocol["name"] == "Uniswap"
    assert is_list(result.pools)
    assert result.custom_analytics == nil
  end
end
