defmodule Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrismTest do
  @moduledoc """
  Test suite for HyperliquidTokenInfoPrism.
  """

  use UnitAPICase, async: false

  import Mock

  alias Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism

  describe "run/1" do
    test "successfully fetches token prices" do
      with_mocks([
        {Lux.Config, [], [
          hyperliquid_account_key: fn -> "0x" <> String.duplicate("1", 64) end,
          hyperliquid_account_address: fn -> "0x0403369c02199a0cb827f4d6492927e9fa5668d5" end,
          hyperliquid_api_url: fn -> "https://api.hyperliquid.xyz" end
        ]},
        {Lux.Python, [], [
          import_package: fn _pkg -> {:ok, %{"success" => true}} end,
          eval!: fn _code, _opts ->
            %{
              "ETH" => %{
                "funding" => "0.0001",
                "openInterest" => "500000.0",
                "prevDayPx" => "2750.0",
                "dayNtlVlm" => "50000000.0",
                "premium" => "0.0002",
                "oraclePx" => "2799.5",
                "markPx" => "2800.0",
                "midPx" => "2800.5",
                "szDecimals" => 4
              }
            }
          end
        ]}
      ]) do
        assert {:ok, response} = HyperliquidTokenInfoPrism.run(%{})
        assert is_map(response.prices)
        assert Map.has_key?(response.prices, "ETH")
        eth_info = response.prices["ETH"]
        assert eth_info["funding"] == "0.0001"
        assert eth_info["markPx"] == "2800.0"
      end
    end
  end
end
